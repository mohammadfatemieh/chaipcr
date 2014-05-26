#include "pcrincludes.h"
#include "pocoincludes.h"

#include "stage.h"
#include "protocol.h"

Protocol::Protocol()
{
    _lidTemperature = 0;
    _currentStage = _stages.end();
}

Protocol::Protocol(const Protocol &other)
    :Protocol()
{
    setLidTemperature(other.lidTemperature());
    setStages(other.stages());
}

Protocol::Protocol(Protocol &&other)
    :Protocol()
{
    _lidTemperature = other._lidTemperature;
    _stages = std::move(other._stages);
    _currentStage = other._currentStage;

    other._lidTemperature = 0;
    other._currentStage = other._stages.end();
}

Protocol::~Protocol()
{

}

Protocol& Protocol::operator= (const Protocol &other)
{
    setLidTemperature(other.lidTemperature());
    setStages(other.stages());

    return *this;
}

Protocol& Protocol::operator= (Protocol &&other)
{
    _lidTemperature = other._lidTemperature;
    _stages = std::move(other._stages);
    _currentStage = other._currentStage;

    other._lidTemperature = 0;
    other._currentStage = other._stages.end();

    return *this;
}

void Protocol::setStages(const std::vector<Stage> &stages)
{
    _stages = stages;

    resetCurrentStep();
}

void Protocol::setStages(std::vector<Stage> &&stages)
{
    _stages = std::move(stages);

    resetCurrentStep();
}

void Protocol::appendStage(const Stage &stage)
{
    _stages.push_back(stage);
}

void Protocol::appendStage(Stage &&stage)
{
    _stages.push_back(std::move(stage));
}

void Protocol::resetCurrentStep()
{
    for (Stage &stage: _stages)
        stage.resetCurrentStep();

    _currentStage = _stages.begin();
}

Step* Protocol::currentStep() const
{
    if (_currentStage != _stages.end())
        return _currentStage->currentStep();
    else
        return nullptr;
}

Ramp* Protocol::currentRamp() const
{
    if (_currentStage != _stages.end())
        return _currentStage->currentRamp();
    else
        return nullptr;
}

Step* Protocol::nextStep()
{
    if (_currentStage == _stages.end())
        return nullptr;

    Step *step = _currentStage->nextStep();

    if (!step)
    {
        ++_currentStage;
        step = currentStep();
    }

    return step;
}
