window.ChaiBioTech.ngApp.directive('autoDeltaToggle', [
  function() {
    return {
      restric: 'EA',
      replace: true,
      templateUrl: 'app/views/directives/gather-data-toggle.html',

      scope: {
        data: '=data',
        type: '@',
        call: "@"
      },

      link: function(scope, elem, attr) {
        scope.show = false;
        scope.$on("dataLoaded", function() {
          scope.$watch("data", function(val, oldVal) {
            scope.configureSwitch(val);
          });

          scope.$watch("type", function(val, oldVal) {
            if(val === "cycling") {
              scope.show = true;
            } else {
              scope.show = false;
            }
          });

        });

        $(elem).click(function(evt) {
          if($(evt.target).is(".gather-data-toggle")) {
            scope.configureSwitch(!scope.data);
            scope.sendData();
          }
        });

        scope.configureSwitch = function(val) {

          if(val) {
            $(scope.dragElem).parent().css("background-color", "#8dc63f");
            $(scope.dragElem).children().css("background-color", "#8dc63f");
            $(scope.dragElem).css("left", "11px");
          } else {
            $(scope.dragElem).parent().css("background-color", "#bbbbbb");
            $(scope.dragElem).children().css("background-color", "#bbbbbb");
            $(scope.dragElem).css("left", "1px");
          }

        };

        scope.sendData = function() {

          scope.data = !scope.data;
          scope.$parent[scope.call]();
        };

        scope.dragElem = $(elem).find(".outer-circle").draggable({
          containment: "parent",
          axis: "x",

          stop: function() {
            var pos = $(this).position().left;
            var val = false;
            if(scope.type === "cycling") {
              if(pos < 6) {
                $(this).css("left", "1px");
              } else {
                $(this).css("left", "11px");
                val = true;
              }
              if(val !== scope.data) {
                scope.sendData();
              }
            } else {
              $(this).css("left", "1px");
            }
          }
        });
      }
    };
  }
]);
