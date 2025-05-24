import java.io.*;
import java.net.*;

Socket socket;
PrintWriter out;
BufferedReader in;
boolean connected = false;

// Polargraph physical parameters (adjust these to match your setup)
float machineWidth = 1400.0;    // Distance between motors in mm
float machineHeight = 1080.0;   // Height of drawing area in mm
float stepsPerMM = 80.0;       // Steps per mm (800 steps/rev, 84mm/rev belt)

// Current position tracking
float currentX = machineWidth / 2;  // Start at center
float currentY = machineHeight / 2;             // Start position Y
float currentL1, currentL2;         // Current string lengths

// Movement parameters
float stepSize = 10.0;         // Movement distance in mm
int feedRate = 4000;           // Feed rate in mm/min (slower for precision)
float segmentLength = 5.0;     // Break moves into small segments for accuracy

void setup() {
  size(800, 700);
  
  // Calculate initial string lengths
  updateStringLengths();
  
  connectToFluidNC();
  
  println("Polargraph WASD Controls:");
  println("Machine Width: " + machineWidth + "mm");
  println("Current Position: X=" + currentX + ", Y=" + currentY);
  println("String Lengths: L1=" + currentL1 + ", L2=" + currentL2);
  println("");
  println("Controls:");
  println("W - Move Up (Y+)");
  println("A - Move Left (X-)");
  println("S - Move Down (Y-)");
  println("D - Move Right (X+)");
  println("Q/E - Step size +/-");
  println("R - Reconnect");
  println("H - Home to center");
  println("ESC - Disconnect");
}

void draw() {
  background(30);
  
  // Draw machine representation
  drawMachineVisualization();
  
  // Display status
  displayStatus();
}

void drawMachineVisualization() {
  // Scale factor for visualization
  float scale = 0.5;
  float offsetX = 50;
  float offsetY = 50;
  
  // Draw machine frame
  stroke(100);
  strokeWeight(2);
  line(offsetX, offsetY, offsetX + machineWidth * scale, offsetY);
  
  // Draw current position
  float visX = offsetX + currentX * scale;
  float visY = offsetY + currentY * scale;
  
  // Draw strings
  stroke(150, 150, 255);
  strokeWeight(1);
  line(offsetX, offsetY, visX, visY);  // L1 string
  line(offsetX + machineWidth * scale, offsetY, visX, visY);  // L2 string
  
  // Draw gondola position
  fill(255, 100, 100);
  noStroke();
  ellipse(visX, visY, 8, 8);
  
  // Draw coordinate system
  stroke(80);
  strokeWeight(1);
  // Grid lines
  for (int i = 0; i <= machineWidth; i += 50) {
    float x = offsetX + i * scale;
    line(x, offsetY, x, offsetY + machineHeight * scale);
  }
  for (int i = 0; i <= machineHeight; i += 50) {
    float y = offsetY + i * scale;
    line(offsetX, y, offsetX + machineWidth * scale, y);
  }
}

void displayStatus() {
  fill(255);
  textAlign(LEFT);
  int yPos = height - 120;
  
  if (connected) {
    fill(0, 255, 0);
    text("● Connected", 20, yPos);
  } else {
    fill(255, 0, 0);
    text("● Disconnected", 20, yPos);
  }
  
  fill(255);
  yPos += 20;
  text("Position: X=" + nf(currentX, 0, 1) + ", Y=" + nf(currentY, 0, 1), 20, yPos);
  yPos += 15;
  text("Strings: L1=" + nf(currentL1, 0, 1) + ", L2=" + nf(currentL2, 0, 1), 20, yPos);
  yPos += 15;
  text("Step Size: " + stepSize + "mm", 20, yPos);
  yPos += 15;
  text("Feed Rate: " + feedRate + "mm/min", 20, yPos);
}

void connectToFluidNC() {
  try {
    if (socket != null && !socket.isClosed()) {
      socket.close();
    }
    
    socket = new Socket("192.168.1.64", 23);
    out = new PrintWriter(socket.getOutputStream(), true);
    in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
    connected = true;
    println("Connected to FluidNC");
    
    // Send initial homing or status
    sendCommand("?");
    
  } catch (Exception e) {
    connected = false;
    println("Connection failed: " + e.getMessage());
  }
}

void sendCommand(String command) {
  if (connected && out != null) {
    try {
      out.println(command);
      println("Sent: " + command);
    } catch (Exception e) {
      println("Send error: " + e.getMessage());
      connected = false;
    }
  } else {
    println("Not connected - cannot send: " + command);
  }
}

void keyPressed() {
  if (!connected) {
    if (key == 'r' || key == 'R') {
      connectToFluidNC();
    }
    return;
  }
  
  float targetX = currentX;
  float targetY = currentY;
  boolean shouldMove = false;
  
  switch (key) {
    case 'w':
    case 'W':
      // Move down (Y-)
      targetY = currentY - stepSize;
      shouldMove = true;
      break;
      
    case 's':
    case 'S':
      // Move up (Y+)
      targetY = currentY + stepSize;
      shouldMove = true;
      break;
      
    case 'a':
    case 'A':
      // Move left (X-)
      targetX = currentX - stepSize;
      shouldMove = true;
      break;
      
    case 'd':
    case 'D':
      // Move right (X+)
      targetX = currentX + stepSize;
      shouldMove = true;
      break;
      
    case 'h':
    case 'H':
      // Home to center
      targetX = machineWidth / 2;
      targetY = 150;
      shouldMove = true;
      break;
      
    case 'q':
    case 'Q':
      stepSize += 5.0;
      if (stepSize > 100) stepSize = 100;
      println("Step size: " + stepSize + "mm");
      break;
      
    case 'e':
    case 'E':
      stepSize -= 5.0;
      if (stepSize < 1.0) stepSize = 1.0;
      println("Step size: " + stepSize + "mm");
      break;
      
    case 'r':
    case 'R':
      connectToFluidNC();
      break;
      
    case '!':
      sendCommand("!");
      println("EMERGENCY STOP SENT");
      break;
      
    case '?':
      sendCommand("?");
      break;
  }
  
  if (shouldMove) {
    // Validate bounds
    if (targetX < 0) targetX = 0;
    if (targetX > machineWidth) targetX = machineWidth;
    if (targetY < 0) targetY = 0;
    if (targetY > machineHeight) targetY = machineHeight;
    
    moveToPosition(targetX, targetY);
  }
  
  if (keyCode == ESC) {
    disconnect();
    key = 0;
  }
}

void moveToPosition(float targetX, float targetY) {
  println("Moving from (" + currentX + "," + currentY + ") to (" + targetX + "," + targetY + ")");
  
  // Calculate total distance
  float totalDist = sqrt(pow(targetX - currentX, 2) + pow(targetY - currentY, 2));
  
  // Break into segments for smooth movement
  int numSegments = max(1, (int)(totalDist / segmentLength));
  
  for (int i = 1; i <= numSegments; i++) {
    // Interpolate position
    float t = (float)i / numSegments;
    float segX = lerp(currentX, targetX, t);
    float segY = lerp(currentY, targetY, t);
    
    // Calculate string lengths for this segment
    float[] stringLengths = calculateStringLengths(segX, segY);
    float newL1 = stringLengths[0];
    float newL2 = stringLengths[1];
    
    // Calculate deltas in mm
    float deltaL1 = newL1 - currentL1;
    float deltaL2 = newL2 - currentL2;
    
    // Send G-code command for this segment
    String command = "$J=G91 G21";
    
    // Convert string length changes to motor movements
    // Assuming X axis controls L1 (left motor) and Y axis controls L2 (right motor)
    if (abs(deltaL1) > 0.1) {  // Only move if significant change
      command += " X" + nf(deltaL1, 0, 3);
    }
    if (abs(deltaL2) > 0.1) {
      command += " Y" + nf(deltaL2, 0, 3);
    }
    
    command += " F" + feedRate;
    
    if (command.contains("X") || command.contains("Y")) {
      sendCommand(command);
      
      // Update current string lengths
      currentL1 = newL1;
      currentL2 = newL2;
      
      // Small delay between segments
      delay(50);
    }
  }
  
  // Update current position
  currentX = targetX;
  currentY = targetY;
  
  println("Movement complete. New position: (" + currentX + "," + currentY + ")");
  println("String lengths: L1=" + currentL1 + ", L2=" + currentL2);
}

float[] calculateStringLengths(float x, float y) {
  // Calculate L1 (left string length) using Pythagorean theorem
  float L1 = sqrt(x * x + y * y);
  
  // Calculate L2 (right string length)
  float L2 = sqrt(pow(machineWidth - x, 2) + y * y);
  
  return new float[]{L1, L2};
}

void updateStringLengths() {
  float[] lengths = calculateStringLengths(currentX, currentY);
  currentL1 = lengths[0];
  currentL2 = lengths[1];
}

void disconnect() {
  try {
    if (socket != null && !socket.isClosed()) {
      socket.close();
    }
    connected = false;
    println("Disconnected from FluidNC");
  } catch (Exception e) {
    println("Disconnect error: " + e.getMessage());
  }
}

void exit() {
  disconnect();
  super.exit();
}