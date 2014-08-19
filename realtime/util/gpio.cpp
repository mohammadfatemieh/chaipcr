#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <sys/eventfd.h>

#include <cstring>
#include <climits>
#include <cassert>

#include <exception>
#include <sstream>
#include <fstream>

#include "pcrincludes.h"
#include "gpio.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////
// Class GPIO
GPIO::GPIO(unsigned int pinNumber, Direction direction) :
	pinNumber_(pinNumber) {
	
	exportPin();
	setDirection(direction);

    stopWaitinigFd_ = eventfd(0, EFD_NONBLOCK);

    savedValue_ = value();
}

GPIO::GPIO(GPIO &&other) {
    pinNumber_ = other.pinNumber_;
    direction_ = other.direction_;
    savedValue_ = other.savedValue_;

    other.pinNumber_ = UINT_MAX;
}

GPIO::~GPIO() {
    unexportPin();
    close(stopWaitinigFd_);
}

GPIO& GPIO::operator= (GPIO &&other) {
    pinNumber_ = other.pinNumber_;
    direction_ = other.direction_;
    savedValue_ = other.savedValue_;

    other.pinNumber_ = UINT_MAX;

    return *this;
}
	
GPIO::Value GPIO::value() const {
    if (pinNumber_ == UINT_MAX)
        throw GPIOError("GPIO is moved");

	ostringstream filePath;
	ifstream valueFile;
	char buf[2];
	
	filePath << "/sys/class/gpio/gpio" << pinNumber_ << "/value";
	valueFile.open(filePath.str());
	valueFile >> buf;
	valueFile.close();
	
	switch (buf[0]) {
	case '0':
        savedValue_ = kLow;
		return kLow;
	
	case '1':
        savedValue_ = kHigh;
		return kHigh;
		
	default:
		throw GPIOError("Unexpected GPIO value");
	}
}

void GPIO::setValue(Value value, bool checkValue) {
    if (pinNumber_ == UINT_MAX)
        throw GPIOError("GPIO is moved");

    if (checkValue && value == savedValue_)
        return;

	if (direction_ != kOutput)
		throw InvalidState("Attempt to set value of non-output GPIO pin");
	
	ostringstream filePath;
	ofstream valueFile;
	
	filePath << "/sys/class/gpio/gpio" << pinNumber_ << "/value";
	valueFile.open(filePath.str());
	
	switch (value) {
    case kInput:
		valueFile << "0";
		break;
	
	case kOutput:
		valueFile << "1";
		break;
	
	default:
		throw invalid_argument("Invalid GPIO value");
	}
	
	valueFile.close();
    savedValue_ = value;
}

GPIO::Value GPIO::waitValue(Value value) {
    if (pinNumber_ == UINT_MAX)
        throw GPIOError("GPIO is moved");

    ostringstream filePath;
    filePath << "/sys/class/gpio/gpio" << pinNumber_ << "/value";

    int gpioFd = open(filePath.str().c_str(), O_RDONLY | O_NONBLOCK);
    if (gpioFd > 0) {
        char buffer[sizeof(int64_t)];
        memset(buffer, 0, sizeof(buffer));
        read(gpioFd, buffer, sizeof(buffer)-1);

        if ((buffer[0] == '0' && value == kLow) || (buffer[0] == '1' && value == kHigh)) {
            savedValue_ = value;
            close(gpioFd);

            return value;
        }

        pollfd fdArray[2];
        fdArray[0].fd = gpioFd;
        fdArray[0].events = POLLPRI;
        fdArray[0].revents = 0;

        fdArray[1].fd = stopWaitinigFd_;
        fdArray[1].events = POLLIN;
        fdArray[1].revents = 0;

        if (poll(fdArray, 2, -1) > 0) {
            if (fdArray[0].revents > 0) { //If was some operation on GPIO
                read(gpioFd, buffer, sizeof(buffer)-1);

                switch (buffer[0]) {
                case '0':
                    value = savedValue_ = kLow;
                    break;

                case '1':
                    value = savedValue_ = kHigh;
                    break;

                default:
                    close(gpioFd);
                    throw GPIOError("Unexpected GPIO value");
                }
            }
            else { //If was some operatio on stopWaitinigFd_
                read(stopWaitinigFd_, buffer, sizeof(int64_t));
                value = value == kHigh ? kLow : kHigh;
            }
        }
        else
            value = value == kHigh ? kLow : kHigh;

        close(gpioFd);
    }
    else
        throw std::logic_error("Unable to open gpio");

    return value;
}

void GPIO::stopWaitinigValue() {
    int64_t i = 1;
    write(stopWaitinigFd_, &i, sizeof(i));
}

void GPIO::setDirection(Direction direction) {
    if (pinNumber_ == UINT_MAX)
        throw GPIOError("GPIO is moved");

	ostringstream filePath;
	ofstream directionFile;
	
	filePath << "/sys/class/gpio/gpio" << pinNumber_ << "/direction";
	directionFile.open(filePath.str());
	
	switch (direction) {
	case kInput:
		directionFile << "in";
		break;
	
	case kOutput:
		directionFile << "out";
		break;
	
	default:
		throw invalid_argument("Invalid direction");
	}
	
	directionFile.close();
	
	direction_ = direction;
}

void GPIO::exportPin() {
    if (pinNumber_ != UINT_MAX) {
        ofstream exportFile;
        exportFile.open("/sys/class/gpio/export");
        exportFile << pinNumber_;
    }
}

void GPIO::unexportPin() {
    if (pinNumber_ != UINT_MAX) {
        ofstream unexportFile;
        unexportFile.open("/sys/class/gpio/unexport");
        unexportFile << pinNumber_;
    }
}
