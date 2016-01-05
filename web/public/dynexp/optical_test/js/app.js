(function () {
  'use strict';

  var App = window.App = angular.module('ThermalConsistency', [
    'ui.router',
    'ngResource',
    'http-auth-interceptor',
    'angularMoment'
  ]);

  App.value('host', 'http://' + window.location.hostname);

})();