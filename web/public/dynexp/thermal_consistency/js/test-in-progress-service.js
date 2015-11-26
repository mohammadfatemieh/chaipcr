window.App.service('TestInProgressService', [
  '$rootScope',
  'Experiment',
  '$q',
  'Status',
  function($rootScope, Experiment, $q, Status) {
    var directivesCount, experiment, experimentQues, holding, isFetchingExp, status;
    directivesCount = 0;
    status = null;
    experiment = null;
    holding = false;
    experimentQues = {};
    isFetchingExp = false;
    $rootScope.$watch((function(_this) {
      return function() {
        return Status.getData();
      };
    })(this), (function(_this) {
      return function(data) {
        status = data;
        return _this.setHolding(status, experiment);
      };
    })(this));
    this.getExperiment = function(id) {
      var deferred, fetchPromise;
      deferred = $q.defer();
      experimentQues["exp_id_" + id] = experimentQues["exp_id_" + id] || [];
      experimentQues["exp_id_" + id].push(deferred);
      if (!isFetchingExp) {
        isFetchingExp = true;
        fetchPromise = Experiment.get({
          id: id
        }).$promise;
        fetchPromise.then((function(_this) {
          return function(resp) {
            var def, i, len, ref, results;
            _this.setHolding(status, experiment);
            experimentQues["exp_id_" + resp.experiment.id] = experimentQues["exp_id_" + resp.experiment.id] || [];
            ref = experimentQues["exp_id_" + resp.experiment.id];
            results = [];
            for (i = 0, len = ref.length; i < len; i += 1) {
              def = ref[i];
              experiment = resp.experiment;
              results.push(def.resolve(experiment));
            }
            return results;
          };
        })(this));
        fetchPromise["catch"](function(err) {
          var def, i, len, results;
          results = [];
          for (i = 0, len = experimentQues.length; i < len; i += 1) {
            def = experimentQues[i];
            def.reject(err);
            results.push(experiment = null);
          }
          return results;
        });
        fetchPromise["finally"](function() {
          isFetchingExp = false;
          return experimentQues["exp_id_" + id] = [];
        });
      }
      return deferred.promise;
    };
    this.isHolding = function() {
      return holding;
    };
    this.setHolding = function(data, experiment) {
      var duration, stages, state, steps;
      if (!experiment) {
        return false;
      }
      if (!experiment.protocol) {
        return false;
      }
      if (!experiment.protocol.stages) {
        return false;
      }
      if (!data) {
        return false;
      }
      if (!data.experimentController) {
        return false;
      }
      stages = experiment.protocol.stages;
      steps = stages[stages.length - 1].stage.steps;
      duration = parseInt(steps[steps.length - 1].step.delta_duration_s);
      state = data.experimentController.machine.state;
      holding = state === 'Complete' && duration === 0;
      return holding;
    };
    this.timeRemaining = function(data) {
      var exp, time;
      if (!data) {
        return 0;
      }
      if (!data.experimentController) {
        return 0;
      }
      if (data.experimentController.machine.state === 'Running') {
        exp = data.experimentController.expriment;
        time = (exp.estimated_duration * 1 + exp.paused_duration * 1) - exp.run_duration * 1;
        if (time < 0) {
          time = 0;
        }
        return time;
      } else {
        return 0;
      }
    };
    this.getExperimentSteps = function (exp) {
      var stages = exp.protocol.stages;
      var steps = [];

      for (var i=0; i < stages.length; i++) {
        var stage = stages[i].stage;
        var _steps = stage.steps;

        for (var ii=0; ii < _steps.length; ii ++) {
          steps.push(_steps[ii].step);
        }
      }
      return steps;
    };
  }
]);

// ---
// generated by coffee-script 1.9.2