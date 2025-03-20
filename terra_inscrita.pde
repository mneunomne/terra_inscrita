
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
boolean saveFrames = true;
boolean animation = false;
boolean setByMouse = false;

void setup() {
  // Setup canvas and background
  size(596, 842, P2D); // A4 paper in pixels (72 dpi)
  
  bg = loadImage("bg.png");
  background(255);
  image(bg, 0, 0, width, height);

  // Initialize PGraphics object
  pg = createGraphics(1000, 1000);
  
  // Initialize components
  mapCoordinator = new MapCoordinator();
  curveManager = new CurveManager();
  serialController = new SerialController(this, 5, curveManager);
  uiManager = new UIManager(this, curveManager);
  
  // Setup websocket server
  setupWebsocketServer();
  
  // Load data and prepare visualization
  curveManager.loadData("rios_barreiras.csv");
  curveManager.calculateCurves();
  uiManager.drawImage();
}

void draw() {
  serialController.listenToPort();
  
  // Draw line tracking current movement
  stroke(0, 0, 0, 125);
  noFill();
  strokeWeight(2);
  PVector prev = serialController.getPrevPosition();
  PVector current = serialController.getCurrentPosition();
  if (prev.x != 0 && prev.y != 0) {
    line(prev.x, prev.y, current.x, current.y);
  }
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