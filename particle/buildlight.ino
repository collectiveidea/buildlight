int greenLED = D6;
int yellowLED = D3;
int redLED = D0;

boolean green_active = true;
boolean yellow_active = true;
boolean red_active = true;

// We start with the setup function.

void setup() {
  // Setup pins
  pinMode(greenLED, OUTPUT);
  pinMode(yellowLED, OUTPUT);
  pinMode(redLED, OUTPUT);

  // Subscribe to events
  Particle.subscribe("build_state", stateHandler);
}

void loop() {
  // Is the green light on?
  if (green_active) {
    digitalWrite(greenLED, HIGH);
  } else {
    digitalWrite(greenLED, LOW);
  }

  // Is the red light on?
  if (red_active) {
    digitalWrite(redLED, HIGH);
  } else {
    digitalWrite(redLED, LOW);
  }

  // Is the yellow light active?
  if (yellow_active) {
    // This should flash the light every second
    if (millis() % 2000 > 1000) {
      digitalWrite(yellowLED, HIGH);
    } else {
      digitalWrite(yellowLED, LOW);
    }
  } else {
    digitalWrite(yellowLED, LOW);
  }
}

void stateHandler(const char *event, const char *data)
{
  if (strcmp(data, "passing") == 0) {
    green_active = true;
    yellow_active = false;
    red_active = false;
  } else if (strcmp(data, "passing-building") == 0) {
    green_active = true;
    yellow_active = true;
    red_active = false;
  } else if (strcmp(data, "failing-building") == 0) {
    green_active = false;
    yellow_active = true;
    red_active = true;
  } else if (strcmp(data, "failing") == 0) {
    green_active = false;
    yellow_active = false;
    red_active = true;
  }
}
