
import processing.serial.*;
import websockets.*;

// Controller instances
CurveManager curveManager;
SerialController serialController;
UIManager uiManager;
MapCoordinator mapCoordinator;

// PGraphics and rendering
PGraphics pg;
PImage bg;

// Configuration
boolean saveFrames = false;
boolean animation = false;
boolean setByMouse = false;

void setup() {
  // Setup canvas and background
  size(1000, 1000, P2D); // A4 paper in pixels (72 dpi)
  
  bg = loadImage("bg.png");
  background(255);

  // Initialize PGraphics object
  pg = createGraphics(1000, 1000);
  
  // Initialize components
  mapCoordinator = new MapCoordinator();
  curveManager = new CurveManager();
  serialController = new SerialController(this, 0, curveManager);
  uiManager = new UIManager(this, curveManager);
  
  // Setup websocket server
  setupWebsocketServer();
  
  // Load data and prepare visualization
  curveManager.loadData("rios_barreiras_escritas3.csv");
  curveManager.calculateCurves();
  curveManager.calculateGCode();
  uiManager.drawImage();
}

void draw() {
  serialController.listenToPort();
  // uiManager.drawImage();
  // Draw line tracking current movement
  background(255);
  image(pg, 0, 0, width, width);
  stroke(255, 0, 0, 125);
  noFill();
  strokeWeight(1);
  PVector prev = serialController.getPrevPosition();
  PVector current = serialController.getCurrentPosition();
  if (prev.x != 0 && prev.y != 0) {
    line(prev.x, prev.y, current.x, current.y);
  }
  strokeWeight(2);
  // draw red circle at current position
  ellipse(current.x, current.y, 20, 20);
}

void keyPressed() {
  if (key == 'a') {
    serialController.sendLine();
    curveManager.incrementCurveIndex();
  }
}

void setupWebsocketServer() {
  WebsocketServer server = new WebsocketServer(this, 8080, "/");
  serialController.setWebsocketServer(server);
}
