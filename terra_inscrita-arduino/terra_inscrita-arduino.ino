#define STEP_PIN_X 2
#define DIR_PIN_X 5

#define STEP_PIN_Y 3
#define DIR_PIN_Y 6

#define ENA_PIN 8

#define microX1 1
#define microX2 3
#define microX3 4

#define microY1 1
#define microY2 3
#define microY3 4

#define limitX 9
#define limitY 10


int numCommands = 11;
String test_commands [11] = {
  "G0 X-49572.0 Y9656.0",
  "G2 X-49440.82 Y9840.347 I65.59277 J92.17395",
  "G3 X-49330.47 Y9988.384 I55.175293 J74.019104",
  "G3 X-49237.24 Y10104.595 I46.613037 J58.10547",
  "G2 X-49157.477 Y10193.473 I39.881104 J44.438232",
  "G2 X-49087.5 Y10259.5 I34.987793 J33.013245",
  "G3 X-49023.645 Y10307.167 I31.924805 J23.833618",
  "G3 X-48962.242 Y10340.964 I30.70044 J16.898315",
  "G3 X-48899.617 Y10365.377 I31.310547 J12.206299",
  "G2 X-48832.094 Y10384.892 I33.763428 J9.757568",
  "G3 X-48756.0 Y10404.0 I38.04663 J9.554199"
};

int steps_per_pixel = 72;
int canvas_width = steps_per_pixel * 1000;
int canvas_height = steps_per_pixel * 1000;


int microdelay = 100;

#include <GCodeParser.h>

GCodeParser GCode = GCodeParser();

int minDelay = 2;
int maxDelayDefault = 100;

boolean reachedXLimit = false;
boolean reachedYLimit = false;

char c;

char buffer[14];

// current position

long curX = 0L;
long curY = 0L;

void setup() {
  Serial.begin(115200);
  
  pinMode(STEP_PIN_X,OUTPUT);
  pinMode(DIR_PIN_X,OUTPUT);

  pinMode(STEP_PIN_Y,OUTPUT);
  pinMode(DIR_PIN_Y,OUTPUT);
  
  pinMode(ENA_PIN,OUTPUT);

  pinMode(limitX, INPUT_PULLUP);
  pinMode(limitY, INPUT_PULLUP);

  start();

  //testCurves();
}

void start () {
  delay(100);

  digitalWrite(ENA_PIN,LOW); // enable motor HIGH -> DISABLE
  //digitalWrite(ENA_PIN,LOW); // enable motor HIGH -> DISABLE
  // initial movement 
  moveX(100L, 1, microdelay, false);
  moveY(100L, -1, microdelay, false);
  moveX(100L, -1, microdelay, false);
  moveY(100L, 1, microdelay, false);

  goHome();

  Serial.println("r");

  // bigSquare();
}

void bigSquare() {
  // go to the top left corner
  //moveTo(0, 0);
  //
  // move(-71000L, 500L , 100);
  //move(-72000L, 72000L , 100);
  //move(-500L, 72000L , 100);
  //move(-500L, 500L , 100);
}

void loop() {
  listenToPort();
}

bool checkLimitX(){
  int limitSwitchX = digitalRead(limitX);
  if (limitSwitchX == LOW) {
    if (!reachedXLimit) {
      Serial.println("end_limit_x");
      Serial.println(String(curX - 1000L));
      reachedXLimit = true;
      curX = 0L;
    }
    return true;
  } else {
    reachedXLimit = false;
    return false;
  }
}

bool checkLimitY() {
  int limitSwitchY = digitalRead(limitY);
  if (limitSwitchY == LOW) {
    if (!reachedYLimit) {
      Serial.println("end_limit_y");
      Serial.println(String(curY + 1000L));
      reachedYLimit = true;
      curY = 0L;
    }
    return true;
  } else {
    reachedYLimit = false;
    return false;
  }
}


void listenToPort() {
  while (Serial.available() > 0) {
    char incomingChar = Serial.read();
    // Add the character to the G-code parser
    if (GCode.AddCharToLine(incomingChar)) { // Process the full line when received
      parseAndExecuteGCode(); // Parse and execute the G-code command
      Serial.println("OK");  // Acknowledge the command
    }
  }
}

void parseAndExecuteGCode() {
  GCode.ParseLine();
  if (GCode.HasWord('G0') || GCode.HasWord('G1')) {
    long x = GCode.GetWordValue('X');
    long y = GCode.GetWordValue('Y');
    move(x, y, microdelay);
  } else if (GCode.HasWord('G2') || GCode.HasWord('G3')) {
    bool clockwise = GCode.HasWord('G2');
    long x = GCode.GetWordValue('X');
    long y = GCode.GetWordValue('Y');
    long i = GCode.GetWordValue('I');
    long j = GCode.GetWordValue('J');
    moveArc(curX, curY, x, y, i, j, clockwise);
  }
}

void goHome () {
  moveX(100000L, 1, microdelay, false);
  moveY(100000L, -1, microdelay, false);
} 


long extractValue(String command, char key, float defaultValue) {
  int index = command.indexOf(key);
  if (index != -1) {
    // to long
    long value = command.substring(index + 1).toFloat();
    return value;
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

    move(x, y, microdelay);
  }
}

// Cubic interpolation function
float cubicInterpolate(float t) {
    return 3 * t * t - 2 * t * t * t;
}

// Custom cubic interpolation function for faster acceleration/deceleration
float customCubicInterpolate(float t) {
    // Custom cubic function to emphasize faster changes
    if (t < 0.5) {
        return 4 * t * t * t; // Faster acceleration
    } else {
        float p = (t - 1);
        return 1 + 4 * p * p * p; // Faster deceleration
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
      if (checkLimitX()) break;
      digitalWrite(STEP_PIN_X, HIGH);
      delayMicroseconds(microdelay);
      digitalWrite(STEP_PIN_X, LOW);
    }
    if (i < stepsY) {
      if (checkLimitY()) break;
      digitalWrite(STEP_PIN_Y, HIGH);
      delayMicroseconds(microdelay);
      digitalWrite(STEP_PIN_Y, LOW);
    }
    delayMicroseconds(microdelay); // Adjust delay for speed control
  }
  curX = x;
  curY = y;
}

void move(long x, long y, int maxDelay) {
  long diffX = x - curX;
  long diffY = y - curY;

  // if maxDelay is not set, use default
  if (maxDelay == 0) {
    maxDelay = maxDelayDefault;
  }

  // Determine the direction for each axis
  int dirX = (diffX > 0) ? 1 : -1;
  int dirY = (diffY > 0) ? 1 : -1;

  // Calculate the total steps for each axis
  long totalStepsX = labs(diffX);
  long totalStepsY = labs(diffY);

  Serial.print("totalStepsX: ");
  Serial.print(String(totalStepsX));
  Serial.print(" Y: ");
  Serial.println(String(totalStepsY));

  if (totalStepsX > 0 && totalStepsY == 0) {
    moveX(totalStepsX, dirX, maxDelay, false);
    return;
  }
  
  if (totalStepsX == 0 && totalStepsY > 0) {
    moveY(totalStepsY, dirY, maxDelay, false);
    return;
  }

  if (totalStepsX == 0 && totalStepsY == 0) {
    return;
  }


  // Determine the larger number of steps
  long maxSteps = max(totalStepsX, totalStepsY);

  // Calculate step size for each axis
  float stepSizeX = (float)totalStepsX / maxSteps;
  float stepSizeY = (float)totalStepsY / maxSteps;

  float stepX = 0;
  float stepY = 0;
  
  int curDelay = maxDelay;
  // Move both axes simultaneously, adjusting step size if needed
  for (int i = 0; i < maxSteps; i++) {
    if (checkLimitX() && checkLimitY()) {
      break;
    }

    stepX += stepSizeX;
    stepY += stepSizeY;

    if (stepX >= 1.0) {
      moveX(1L, dirX, curDelay, false);
      curX += 1*dirX;
      stepX -= 1.0;
    }

    if (stepY >= 1.0) {
      moveY(1L, dirY, curDelay, false);
      curY += 1*dirY;
      stepY -= 1.0;
    }
  }
  curX = x;
  curY = y;
}

void moveX (long steps, int dir, int microdelay, bool ignoreLimit) {
  if (dir > 0) {
      digitalWrite(DIR_PIN_X,LOW); // enable motor HIGH -> DISABLE
  } else {
      digitalWrite(DIR_PIN_X,HIGH); // enable motor HIGH -> DISABLE
  }
  for (int i = 0; i < steps; i++) {
    if (checkLimitX() && !ignoreLimit) {
      moveX(1000L, -dir, microdelay, true);
      return;
    }
    curX += 1 * dir;
    digitalWrite(STEP_PIN_X,HIGH);
    delayMicroseconds(microdelay);
    digitalWrite(STEP_PIN_X,LOW);
    delayMicroseconds(microdelay);
  }
  
}
void moveY(long steps, int dir, int microdelay, bool ignoreLimit) {
  // Set direction for both motors
  digitalWrite(DIR_PIN_Y, (dir > 0) ? LOW : HIGH);
  delayMicroseconds(1); // Small delay to allow direction change to take effect

  for (long i = 0; i < steps; i++) {
    if (checkLimitY() && !ignoreLimit) {
      moveY(1000L, -dir, microdelay, true);
      return; // Stop instead of making a recursive call
    }

    curY += dir; // Update position counter

    // Step both motors simultaneously
    digitalWrite(STEP_PIN_Y, HIGH);  
    delayMicroseconds(microdelay);
    digitalWrite(STEP_PIN_Y, LOW);
    delayMicroseconds(microdelay);
  }
}
