/*
 * Giving Credit where Credit Is Due
 *
 * Portions of this code were derived from code posted in the Arduino forums by Paul Malmsten.
 * You can find the original thread here: http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1176098434
 *
 * The Audio portion of the code was derived from the Melody tutorial on the Arduino wiki
 * You can find the original tutorial here: http://arduino.cc/en/Tutorial/Melody
 */
//#include <AikoDevices.h>
#include <AikoEvents.h>
#include <LiquidCrystal.h>



using namespace Aiko;
//using namespace Device;

#define releaseBanner "LaserTag Geo 2.3"
#define sensorPin  2      // Sensor pin 1
#define senderPin  3      // Infrared LED on Pin 3
#define triggerPin 4      // Pushbutton Trigger on Pin 4
#define reloadPin  5      // Added by george Patterson

//#define lcdRS      6
//#define lcdEnable  7
//#define lcdD4      8
//#define lcdD5      9
//#define lcdD6      10
//#define lcdD7      11

#define speakerPin 12     // Positive Lead on the Piezo
#define blinkPin   13     // Positive Leg of the LED we will use to indicate signal is received

#define startBit  2000    // This pulse sets the threshold for a transmission start bit
#define endBit    3000    // This pulse sets the threshold for a transmission end bit
#define one       1000    // This pulse sets the threshold for a transmission that represents a 1
#define zero       400    // This pulse sets the threshold for a transmission that represents a 0

// initialize the library with the numbers of the interface pins
//LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
//These pins are probably incorrect!
//LiquidCrystal lcd(lcdRS, lcdEnable, lcdD4, lcdD5, lcdD6, lcdD7);


int trigger;              // This is used to hold the value of the trigger read;
boolean fired     = false;  // Boolean used to remember if the trigger has already been read.
int reload;                 // This is used to hold the value of the reload read;
boolean reloaded  = false;  // Boolean used to remember if the reload button has already been read.

int ret[2];               // Used to hold results from IR sensing.
#define waitTime  300     // The amount of time to wait between pulses

#define playerLine 14     // Any player ID >= this value is a referee, < this value is a player;
byte myCode     =   3;    // This is your unique player code; //Make this dynamic. Either fetch it from the server whentas server is found, or read it from the RFBee chipset.
int myLevel     =   1;    // This is your starting level;
int maxShots    =   30;    // You can fire 6 safe shots;
int maxHits     =   6;    // After 6 hits you are dead;
int myShots     =   0;    // You can fire 6 safe shots;
int myHits      =   0;    // After 6 hits you are dead;

// Added by George Patterson
#define maxReloads  4
int myReloads = 0;

#define maxLevel    9      // You cannot be promoted past level 9;
#define minLevel    0      // You cannot be demoted past level 0

#define refPromote  0      // The refCode for promotion;
#define refDemote   1      // The refCode for demotion;
#define refReset    2      // The refCode for ammo reset;
#define refRevive   3      // The refCode for revival;

#define replySucc  14     // the player code for Success;
#define replyFail  15
// the player code for Failed;

void setup() {
  pinMode(blinkPin, OUTPUT);
  pinMode(speakerPin, OUTPUT);
  pinMode(senderPin, OUTPUT);
  pinMode(triggerPin, INPUT);
  digitalWrite(triggerPin, HIGH); // Enable the pin's internal pull up resistors
  pinMode(sensorPin, INPUT);
  pinMode(reloadPin, INPUT);
  digitalWrite(reloadPin, HIGH); // Enable the pin's internal pull up resistors
  randomSeed(analogRead(0));
 
  // This line is temporary.. for debugging purposes 
  Serial.println(releaseBanner); 
  //lcd.setCursor(0,0);
  //lcd.print(releaseBanner);
  
  for (int i = 1; i < 4; i++) {
    digitalWrite(blinkPin, HIGH);
    playTone(900*i, 200);
    digitalWrite(blinkPin, LOW);
    delay(200);
  }

  Serial.begin(9600);
  //This should be only written out to the LCD.. when implemented
  //lcd.setCursor(0,0);
  //lcd.print("Ready!");
  Serial.println("Ready ");
  Events.addHandler(senseFire, 100);
  Events.addHandler(senseReload, 100);
  Events.addHandler(displayTime, 1000);
}

void loop() {
  //senseFire();
  //senseReload();
  senseIR();

  if (ret[0] != -1) {
    playTone(1000, 50);
    Serial.print("Who: ");
    Serial.print(ret[0]);
    Serial.print(" What: ");
    Serial.println(ret[1]);
    //lcd.setCursor(0,0);
    //lcd.print("Shot by: ");
    // The following commented line might be required!
    //lcd.setCursor(0,9);
    //lcd.print(ret[0]);
    if (ret[0] >= playerLine) {
      if (ret[1] == refPromote) {
        // Promote 
        if (myLevel < maxLevel) {
          Serial.println("PROMOTED!");
          myLevel++;
          playTone(900, 50);
          playTone(1800, 50);
          playTone(2700, 50);
        }
      } 
      else if (ret[1] == refDemote) {
        // demote
        if (myLevel > minLevel) {
          Serial.println("DEMOTED!");
          myLevel--;
        }
        playTone(2700, 50);
        playTone(1800, 50);
        playTone(900, 50);
      } 
      else if (ret[1] == refReset) {
        Serial.println("AMMO RESET!");
        myShots = maxShots;
        playTone(900, 50);
        playTone(450, 50);
        playTone(900, 50);
        playTone(450, 50);
        playTone(900, 50);
        playTone(450, 50);
      } 
      else if (ret[1] == refRevive) {
        Serial.println("REVIVED!");
        myShots = 0;
        myHits = 0;
        myLevel = 1;
        playTone(900, 50);
        playTone(1800, 50);
        playTone(900, 50);
        playTone(1800, 50);
        playTone(900, 50);
        playTone(800, 50);
      }
    } 
    else {
      if (ret[1] == replySucc) {
        playTone(9000, 50);
        playTone(450, 50);
        playTone(9000, 50);
        Serial.println("SUCCESS!");        
      } 
      else if (ret[1] == replyFail) {
        playTone(450, 50);
        playTone(9000, 50);
        playTone(450, 50);
        Serial.println("FAILED!");        
      }
      if (ret[1] <= maxLevel && ret[1] >= myLevel && myHits <= maxHits) {
        Serial.println("HIT!");
        myHits++;
        playTone(4000, 50);
        playTone(900, 50);
        playTone(4000, 50);
        playTone(900, 50);
      }
    }
  }
  Events.loop();
}

void senseIR() {
  int who[4];
  int what[4];
  int end;
  if (pulseIn(sensorPin, LOW, 50) < startBit) {
    digitalWrite(blinkPin, LOW);
    ret[0] = -1;
    return;
  }
  digitalWrite(blinkPin, HIGH);
  who[0]   = pulseIn(sensorPin, LOW);
  who[1]   = pulseIn(sensorPin, LOW);
  who[2]   = pulseIn(sensorPin, LOW);
  who[3]   = pulseIn(sensorPin, LOW);
  what[0]  = pulseIn(sensorPin, LOW);
  what[1]  = pulseIn(sensorPin, LOW);
  what[2]  = pulseIn(sensorPin, LOW);
  what[3]  = pulseIn(sensorPin, LOW);
  end      = pulseIn(sensorPin, LOW);
  if (end <= endBit) {
    Serial.print(end);
    Serial.println(" : bad end bit");
    ret[0] = -1;
    return;
  }
  Serial.println("---who---");
  for(int i=0;i<=3;i++) {
    //Serial.println(who[i]);
    if(who[i] > one) {
      who[i] = 1;
    } 
    else if (who[i] > zero) {
      who[i] = 0;
    } 
    else {
      // Since the data is neither zero or one, we have an error
      Serial.println("unknown player");
      ret[0] = -1;
      return;
    }
  }
  ret[0]=convert(who);
  Serial.println(ret[0]);

  Serial.println("---what---");
  for(int i=0;i<=3;i++) {
    Serial.println(what[i]);
    if(what[i] > one) {
      what[i] = 1;
    } 
    else if (what[i] > zero) {
      what[i] = 0;
    } 
    else {
      // Since the data is neither zero or one, we have an error
      Serial.println("unknown action");
      ret[0] = -1;
      return;
    }
  }
  ret[1]=convert(what);
  Serial.println(ret[1]);
  return;
}

void playTone(int tone, int duration) {
  for (long i = 0; i < duration * 1000L; i += tone * 2) {
    digitalWrite(speakerPin, HIGH);
    delayMicroseconds(tone);
    digitalWrite(speakerPin, LOW);
    delayMicroseconds(tone);
  }
}

int convert(int bits[]) {
  int result = 0;
  int seed   = 1;
  for(int i=3;i>=0;i--) {
    if(bits[i] == 1) {
      result += seed;
    }
    seed = seed * 2;
  }
  return result;
}

void displayTime() {
  // This procedure will need to be fleshed out to display the game time(s)
  //lcd.setCursor(0,1);
  //lcd.print (millis()/1000);
}

void senseFire() {
  trigger = digitalRead(triggerPin);
  if (trigger == LOW && fired == false) {
    //Serial.println("Fire Button Pressed");
    fired = true;
    myShots++;
    if (myHits <= maxHits && myShots > maxShots && random(1,20) <= myShots) {
      Serial.println("Out of Ammo");
      selfDestruct();
    } 
    else if (myHits <= maxHits) {
      //Serial.print("Firing Shot: ");
      Serial.println(myShots);
      fireShot(myCode, myLevel);
    }
  } 
  else if (trigger == HIGH) {
    if (fired == true) {
      //Serial.println("Fire Button Released");
    }
    // reset the fired variable
    fired = false;
  }
}

void senseReload() {
  reload = digitalRead(reloadPin);
  if (reload == LOW && reloaded == false) {
    Serial.println("Reload Button Pressed");
    reloaded = true;
    //myShots++;
    //Serial.println("AMMO RESET!");
    myShots = 0;
    myHits=maxHits;
    //if (myHits <= maxHits && myShots > maxShots && random(1,20) <= myShots) {
    //  Serial.println("SELF DESTRUCT");
    //  selfDestruct();
    //} 
    //else if (myHits <= maxHits) {
    //  Serial.print("Reloading: ");
    //  Serial.println(myShots);
    //  fireShot(myCode, myLevel);
    //}
  } 
  else if (reload == HIGH) {
    if (reloaded == true) {
      Serial.println("Reload Button Released");
    }
    // reset the fired variable
    reloaded = false;
  }
}

void fireShot(int player, int level) {
  int encoded[8];
  digitalWrite(blinkPin, HIGH);
  for (int i=0; i<4; i++) {
    encoded[i] = player>>i & B1;   //encode data as '1' or '0'
  }
  for (int i=4; i<8; i++) {
    encoded[i] = level>>i & B1;
  }
  // send startbit
  oscillationWrite(senderPin, startBit);
  // send separation bit
  digitalWrite(senderPin, HIGH);
  delayMicroseconds(waitTime);
  // send the whole string of data
  for (int i=7; i>=0; i--) {
    if (encoded[i] == 0) {
      oscillationWrite(senderPin, zero);
    } 
    else {
      oscillationWrite(senderPin, one);
    }
    // send separation bit
    digitalWrite(senderPin, HIGH);
    delayMicroseconds(waitTime);
  }
  oscillationWrite(senderPin, endBit);
  playTone(1000, 25);
  digitalWrite(blinkPin, LOW);
}

void oscillationWrite(int pin, int time) {
  for(int i = 0; i <= time/26; i++) {
    digitalWrite(pin, HIGH);
    delayMicroseconds(13);
    digitalWrite(pin, LOW);
    delayMicroseconds(13);
  }
}

void selfDestruct() {
  myHits  = maxHits+1;
  playTone(1000, 250);
  playTone(750, 250);
  playTone(500, 250);
  playTone(250, 250);
}



