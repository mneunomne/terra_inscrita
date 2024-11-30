#define STEP_PIN_X 2
#define DIR_PIN_X 5
#define STEP_PIN_Y 3
#define DIR_PIN_Y 6
#define ENA_PIN 8

#include <GCodeParser.h>    

GCodeParser GCode = GCodeParser();


long curX = 0L;
long curY = 0L;

int steps_per_pixel = 68;

void setup() {
  Serial.begin(115200);

  pinMode(STEP_PIN_X, OUTPUT);
  pinMode(DIR_PIN_X, OUTPUT);
  pinMode(STEP_PIN_Y, OUTPUT);
  pinMode(DIR_PIN_Y, OUTPUT);
  pinMode(ENA_PIN, OUTPUT);

  digitalWrite(ENA_PIN, LOW); // Enable motors
  Serial.println("Ready");
}

void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    handleCommand(command);
  }
}

void handleCommand(String command) {
  command.trim();

  if (command.startsWith("G2") || command.startsWith("G3")) {
    bool clockwise = command.startsWith("G2");
    float x = extractValue(command, 'X', curX / steps_per_pixel);
    float y = extractValue(command, 'Y', curY / steps_per_pixel);
    float i = extractValue(command, 'I', 0);
    float j = extractValue(command, 'J', 0);

    moveArc(curX, curY, x * steps_per_pixel, y * steps_per_pixel, i * steps_per_pixel, j * steps_per_pixel, clockwise);
    curX = x * steps_per_pixel;
    curY = y * steps_per_pixel;
  }
}

float extractValue(String command, char key, float defaultValue) {
  int index = command.indexOf(key);
  if (index != -1) {
    return command.substring(index + 1).toFloat();
  }
  return defaultValue;
}

void moveArc(long startX, long startY, long endX, long endY, long i, long j, bool clockwise) {
  float cx = startX + i;
  float cy = startY + j;
  float radius = sqrt(i * i + j * j);

  float startAngle = atan2(startY - cy, startX - cx);
  float endAngle = atan2(endY - cy, endX - cx);

  if (clockwise && endAngle > startAngle) endAngle -= 2 * M_PI;
  if (!clockwise && endAngle < startAngle) endAngle += 2 * M_PI;

  int steps = 100; // Resolution of the arc
  for (int s = 0; s <= steps; s++) {
    float t = (float)s / steps;
    float angle = startAngle + t * (endAngle - startAngle);

    long x = cx + radius * cos(angle);
    long y = cy + radius * sin(angle);

    moveTo(x, y);
  }
}

void moveTo(long x, long y) {
  long diffX = x - curX;
  long diffY = y - curY;

  int dirX = (diffX > 0) ? LOW : HIGH;
  int dirY = (diffY > 0) ? LOW : HIGH;

  digitalWrite(DIR_PIN_X, dirX);
  digitalWrite(DIR_PIN_Y, dirY);

  long stepsX = abs(diffX);
  long stepsY = abs(diffY);
  long steps = max(stepsX, stepsY);

  for (long i = 0; i < steps; i++) {
    if (i < stepsX) {
      digitalWrite(STEP_PIN_X, HIGH);
      delayMicroseconds(1);
      digitalWrite(STEP_PIN_X, LOW);
    }
    if (i < stepsY) {
      digitalWrite(STEP_PIN_Y, HIGH);
      delayMicroseconds(1);
      digitalWrite(STEP_PIN_Y, LOW);
    }
    delayMicroseconds(100); // Adjust delay for speed control
  }
  curX = x;
  curY = y;
}
