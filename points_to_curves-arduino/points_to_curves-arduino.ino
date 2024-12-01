#define SERIAL_RX_BUFFER_SIZE 1024
const int numChars = 99;           // Maximum size of each command
const int maxCommands = 10;         // Maximum number of commands in the queue
char commandQueue[maxCommands][numChars]; // Queue to store G-code commands
int queueHead = 0;                  // Points to the next command to execute
int queueTail = 0;                  // Points to where the next command is stored
boolean queueFull = false;          // Indicates if the queue is full
boolean newData = false;            // Flag for new data

void setup() {
    Serial.begin(115200);
    Serial.println("<Arduino ready>");
}

void loop() {
    recvWithStartEndMarkers(); // Read and queue incoming data
    processNextCommand();      // Execute the next command in the queue
}

void recvWithStartEndMarkers() {
    static boolean recvInProgress = false;
    static int ndx = 0;
    char startMarker = '<';
    char endMarker = '>';
    char rc;

    while (Serial.available() > 0) {
        rc = Serial.read();
        Serial.print(rc); 
        if (recvInProgress) {
            if (rc != endMarker) {
                if (ndx < numChars - 1) { // Prevent overflow
                    commandQueue[queueTail][ndx] = rc;
                    ndx++;
                }
            } else { // End marker received
                commandQueue[queueTail][ndx] = '\0'; // Null-terminate
                recvInProgress = false;
                ndx = 0;
                enqueueCommand(); // Add to queue
            }
        } else if (rc == startMarker) {
            recvInProgress = true;
        }
    }
}

void enqueueCommand() {
    if (!queueFull) {
        queueTail = (queueTail + 1) % maxCommands; // Move to the next position
        if (queueTail == queueHead) { // Check if the queue is full
            queueFull = true;
        }
    } else {
        Serial.println("Queue full! Command discarded.");
    }
}

void processNextCommand() {
    if (queueHead != queueTail || queueFull) {
        // Execute the command at the head of the queue
        Serial.println(commandQueue[queueHead]);

        // Simulate G-code execution with a delay (replace with actual execution logic)
        delay(100); // Simulates time taken to process the command

        // Remove the command from the queue
        queueHead = (queueHead + 1) % maxCommands;
        queueFull = false;
    }
}
