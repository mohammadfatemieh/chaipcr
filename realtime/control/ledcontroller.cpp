#include "pcrincludes.h"
#include "utilincludes.h"

#include "ledcontroller.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////
// Class LEDController
LEDController::LEDController(SPIPort spiPort, float dutyCyclePercentage):
    _spiPort(move(spiPort)),
    _potCSPin(kLEDDigiPotCSPinNumber, GPIO::kOutput),
    _ledXLATPin(kLEDControlXLATPinNumber, GPIO::kOutput),
    _ledBlankPWM(kLEDBlankPWMPath) {

    _dutyCyclePercentage.store(dutyCyclePercentage);

    _grayscaleClock = make_shared<PWMPin>(kLEDGrayscaleClockPWMPath);
    _grayscaleClock->setPWM(kGrayscaleClockPwmDutyNs, kGrayscaleClockPwmPeriodNs, 0);
    _ledBlankPWM.setPWM(kLedBlankPwmDutyNs, kLedBlankPwmPeriodNs, 0);

	setIntensity(kMinLEDCurrent);

    _potCSPin.setValue(GPIO::kHigh);
    _ledXLATPin.setValue(GPIO::kLow);
}

LEDController::~LEDController() {
	
}
	
void LEDController::setIntensity(double onCurrentMilliamps) {
	//verify current
    if (onCurrentMilliamps < kMinLEDCurrent)
		throw InvalidArgument("onCurrent too low");
    double avgCurrentMilliamps = onCurrentMilliamps * _dutyCyclePercentage / 100;
    if (avgCurrentMilliamps > 30 || onCurrentMilliamps > 100)
		throw InvalidArgument("onCurrent too high");
	
	//calculate 
    double rIref = 1.24 / (onCurrentMilliamps / 1000) * 31.5; //reference resistance for TLC5940
    int rN = (rIref - 75) * 256 / 5000;
    char txBuf[] = {0, static_cast<uint8_t>(rN)};
    cout << "onCurrent = " << onCurrentMilliamps << ", rIref " << rIref << ", rN = " << rN << endl;

    //send resistance
    _potCSPin.setValue(GPIO::kLow);
    _spiPort.setMode(0);
    _spiPort.readBytes(NULL, txBuf, sizeof(txBuf), 1000000);
    _potCSPin.setValue(GPIO::kHigh);

    _intensity = onCurrentMilliamps;
}

void LEDController::activateLED(unsigned int ledNumber) {
    unsigned int pwm = 4096 * _dutyCyclePercentage / 100;
	uint16_t intensities[16];
	memset(intensities, 0, sizeof(intensities));
	intensities[15 - (ledNumber - 1)] = pwm;

	uint8_t packedIntensities[24];

	for (int i = 0; i < 16; i += 2) {
		uint16_t val1 = intensities[i];
		uint16_t val2 = intensities[i+1];

		int packIndex = i * 3 / 2;
		packedIntensities[packIndex] = val1 >> 4;
		packedIntensities[packIndex + 1] = (val1 & 0x000F) << 4 | (val2 & 0x0F00) >> 8;
		packedIntensities[packIndex + 2] = val2 & 0x00FF;
		//cout << "index: " << packIndex << " " << (int)packedIntensities[packIndex] << " " << (int)packedIntensities[packIndex+1] << " " << (int)packedIntensities[packIndex+2] << endl;
	}

    _spiPort.setMode(3);
    _spiPort.readBytes(NULL, (char*)packedIntensities, sizeof(packedIntensities), 1000000);
    _ledXLATPin.setValue(GPIO::kHigh);
    _ledXLATPin.setValue(GPIO::kLow);

    cout << "LED SPI sent" << endl;
}

void LEDController::disableLEDs() {
	
}
	
// --- private member functions ------------------------------------------------
