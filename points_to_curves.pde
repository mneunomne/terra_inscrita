// lines

Table table;
PVector[] points;

void setup() {
  size(900, 900);
  background(255);

  // Load the CSV file
  table = loadTable("rios.csv", "header");
  
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

  // Draw the path
  stroke(0);
  noFill();
  beginShape();
  for (PVector p : points) {
    vertex(p.x, p.y);
  }
  endShape();
}
