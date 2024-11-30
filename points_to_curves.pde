Table table;
PVector[] points;

ArrayList<ArrayList<PVector>> curves = new ArrayList<ArrayList<PVector>>();

PGraphics pg;
float D = 50; // Distance threshold to simplify points into one curve
float d = 2;

boolean saveFrames = true;
boolean animation =false;
boolean setByMouse = false;
PImage bg;

// gcode text file
PrintWriter output;

void setup() {
  size(596, 842, P2D); // a4 paper in pixels (72 dpi) 595 x 842
  bg = loadImage("bg.png");
  background(255);
  image(bg, 0, 0, width, height);

  output = createWriter("output.gcode");

  // Initialize the PGraphics object
  pg = createGraphics(1000, 1000);

  // Load the CSV file
  table = loadTable("rios_barreiras.csv", "header");

  // monospaced font  
  PFont font = createFont("Courier New", 12);
  
  // Check if the table loaded successfully
  if (table == null) {
    println("Failed to load the CSV file.");
    exit();
  }

  // Parse the points from the CSV file
  points = new PVector[table.getRowCount()];
  for (int i = 0; i < table.getRowCount(); i++) {
    float x = table.getFloat(i, "x"); // Replace 'x' with the actual column name if different
    float y = table.getFloat(i, "y"); // Replace 'y' with the actual column name if different
    points[i] = new PVector(x, y);
  }

  noLoop();
}

void drawBezierCurve(PGraphics pg, ArrayList<PVector> group) {
  pg.stroke(random(10), 180 + random(30)); // Random color for each curve

  // Use the first and last points as anchors
  PVector p0 = group.get(0);
  PVector p3 = group.get(group.size() - 1);

  // Calculate control points as the average positions of intermediate points
  PVector p1 = group.get(floor(group.size() / 3));
  PVector p2 = group.get(floor(2 * group.size() / 3));

  pg.beginShape();
  pg.strokeWeight(1);
  pg.vertex(p0.x, p0.y);
  pg.bezierVertex(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
  pg.endShape();

  curves.add(group);

  String gcode = bezierToGcode(p0, p1, p2, p3);
  println(gcode);

  output.println(gcode);
}

String bezierToGcode(PVector p0, PVector p1, PVector p2, PVector p3) {
  StringBuilder gcode = new StringBuilder();
  gcode.append("G0 X").append(p0.x).append(" Y").append(p0.y).append("\n"); // Move to start point
  
  // Approximate the Bezier curve with small arcs
  int steps = 10;
  PVector prevPoint = p0;
  for (int i = 1; i <= steps; i++) {
    float t = i / (float) steps;
    PVector p = bezierPoint(p0, p1, p2, p3, t);
    PVector center = calculateArcCenter(prevPoint, p);
    if (center != null) {
      float radius = prevPoint.dist(center);
      boolean clockwise = isClockwise(prevPoint, p, center);
      gcode.append(clockwise ? "G2" : "G3")
           .append(" X").append(p.x)
           .append(" Y").append(p.y)
           .append(" I").append(center.x - prevPoint.x)
           .append(" J").append(center.y - prevPoint.y)
           .append("\n");
    } else {
      gcode.append("G1 X").append(p.x).append(" Y").append(p.y).append("\n");
    }
    prevPoint = p;
  }
  
  return gcode.toString();
}

PVector bezierPoint(PVector p0, PVector p1, PVector p2, PVector p3, float t) {
  float x = bezierPoint(p0.x, p1.x, p2.x, p3.x, t);
  float y = bezierPoint(p0.y, p1.y, p2.y, p3.y, t);
  return new PVector(x, y);
}

float bezierPoint(float a, float b, float c, float d, float t) {
  float t1 = 1.0 - t;
  return t1 * t1 * t1 * a + 3 * t1 * t1 * t * b + 3 * t1 * t * t * c + t * t * t * d;
}

PVector calculateArcCenter(PVector p1, PVector p2) {
  // Simplified calculation for the arc center
  // This is a placeholder and should be replaced with a proper arc fitting algorithm
  float midX = (p1.x + p2.x) / 2;
  float midY = (p1.y + p2.y) / 2;
  return new PVector(midX, midY);
}

boolean isClockwise(PVector p1, PVector p2, PVector center) {
  // Determine if the arc is clockwise
  float crossProduct = (p2.x - p1.x) * (center.y - p1.y) - (p2.y - p1.y) * (center.x - p1.x);
  return crossProduct < 0;
}

void draw () {
  image(bg, 0, 0, width, height);
  
  // Draw the path on the PGraphics object
  pg.beginDraw();
  pg.background(255, 0);
  pg.strokeWeight(1);
  pg.noFill();

  // clear curves
  curves.clear();

  ArrayList<PVector> group = new ArrayList<PVector>();
  float accumulatedDistance = 0;

  for (int i = 1; i < points.length; i++) {
    PVector p0 = points[i - 1];
    PVector p1 = points[i];
    float dist = p0.dist(p1); // Calculate distance between successive points
    accumulatedDistance += dist;
    group.add(p0);

    if (accumulatedDistance >= D || i == points.length - 1) {
      // Add the last point of the group
      group.add(p1);

      // Simplify the group into one Bezier curve
      if (group.size() >= 3) {
        drawBezierCurve(pg, group);
      } else {
        // Draw a straight line for small groups
        pg.beginShape();
        for (PVector p : group) {
          pg.vertex(p.x, p.y);
        }
        pg.endShape();
      }

      // Reset for the next group
      group.clear();
      accumulatedDistance = 0;
    }
  }

  if (setByMouse) D= mouseY;
  // display lines_count
  pg.fill(0);
  pg.stroke(0);
  pg.textSize(20);
  pg.text("curves: " + curves.size(), 40, 60);
  pg.text("distance: " + D, 40, 80);

    pg.filter(BLUR, 1.1);


  pg.endDraw();

  // Display the PGraphics object scaled to the screen
  image(pg, 0, (height-width) /2, width, width);
  
  if (animation) {
    D+=d;
    if (d > 0) {
      d = d * 1.005;
    } else {
      d = d - 0.1;
    }
    if(D > 2000) {
      d*=-1;
    }
    if (D < 2) {
      saveFrames = false;
    }
    if (saveFrames) {
      saveFrame("frames/####.png");
    }
  }

  output.flush();  // Writes the remaining data to the file
  output.close();  // Finishes the file
}
