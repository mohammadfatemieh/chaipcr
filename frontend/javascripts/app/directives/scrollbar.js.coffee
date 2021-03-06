###
Chai PCR - Software platform for Open qPCR and Chai's Real-Time PCR instruments.
For more information visit http://www.chaibio.com
Copyright 2016 Chai Biotechnologies Inc. <info@chaibio.com>
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
  http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###
window.ChaiBioTech.ngApp.directive 'scrollbar', [
  'TextSelection'
  '$timeout'
  (textSelection, $timeout) ->
    restrict: 'E'
    replace: true
    template: '<div class="scrollbar-directive"></div>'
    scope:
      state: '=' # [{0..1}, width]
    require: 'ngModel'
    link: ($scope, elem, attr, ngModel) ->

      elem.css(width: '100%', cursor: 'pointer')
      # width = elem.width()
      height = 5

      held = false
      oldMargin = 0;
      newMargin = 0;
      pageX = 0
      margin = 0
      spaceWidth = 0
      scrollbar_width = 0
      xDiff = 0
      scrollbarBGClicked = false
      svg = null
      scrollbarBG = null
      scrollbarHandle = null
      resizeTimeout = null

      init = ->
        width = elem.width()

        svg = d3.select(elem[0]).append('svg')
                                  .attr('width', width)
                                  .attr('height', height)

        scrollbarBG = svg.append('rect')
                            .attr('fill', '#ccc')
                            .attr('width', width)
                            .attr('height', height)
                            .attr('rx', 2)
                            .attr('ry', 2)
                            .on 'mousedown', ->
                              scrollbarBGClicked = true
                              oldMargin = getMarginLeft()
                              spaceWidth = getSpaceWidth()
                              scrollbar_width = getScrollBarWidth()
                            .on 'mouseup', ->
                              if scrollbarBGClicked
                                scrollbarBGClicked = false
                                x = d3.mouse(this)[0]
                                newMargin = x - (getScrollBarWidth()/2)

                                updateMargin(newMargin)

                                # avoid dividing with spaceWidth = 0, else result is NaN
                                val = if spaceWidth > 0 then Math.round((newMargin)/spaceWidth*1000)/1000 else 0
                                ngModel.$setViewValue({
                                  value: val,
                                  width: scrollbar_width / getElemWidth()
                                })

        handleWidth = width * getModelWidth()
        scrollbarHandle = svg.append('rect')
                            .attr('fill', '#555')
                            .attr('width', handleWidth)
                            .attr('height', height)
                            .attr('rx', 2)
                            .attr('ry', 2)

        updateMargin(getModelValue() * (width - handleWidth))

        angular.element(scrollbarHandle.node()).on 'mousedown', (e) ->
          held = true
          pageX = e.pageX
          textSelection.disable()

          oldMargin = getMarginLeft()
          spaceWidth = getSpaceWidth()
          scrollbar_width = getScrollBarWidth()

        $scope.$on 'window:mousemove', (event, e) ->
          if held
            xDiff = e.pageX - pageX
            newMargin = oldMargin + xDiff

            updateMargin(newMargin)

            # avoid dividing with spaceWidth = 0, else result is NaN
            val = if spaceWidth > 0 then Math.round((newMargin)/spaceWidth*1000)/1000 else 0
            ngModel.$setViewValue({
              value: val,
              width: scrollbar_width / getElemWidth()
            })


        $scope.$on 'window:mouseup', (event, e) ->
          if held
            held = false
            textSelection.enable()

        $scope.$watchCollection ->
          ngModel.$viewValue
        , (val, oldVal) ->
          if (val?.value isnt oldVal?.value or val?.width isnt oldVal?.width) and !held
            value = val.value*1 || getModelValue()
            value = if (value > 1) then 1 else value
            value = if (value < 0) then 0 else value

            elem_width = getElemWidth()
            width_percent = if angular.isNumber(val.width) then val.width else (if angular.isNumber(ngModel.$viewValue.width) then ngModel.$viewValue.width else 1)
            new_width = elem_width * width_percent
            new_width = if new_width >= 15 then new_width else 15
            scrollbarHandle.attr('width', new_width)
            new_margin = (elem_width - new_width) * value
            updateMargin(new_margin)

        $scope.$on 'window:resize', ->
          width = elem.parent().width()
          svg.attr('width', width)
          scrollbarBG.attr('width', width)
          scrollbarHandle.attr('width', width)
          elem.parent().css(overflow: 'hidden')

          if (resizeTimeout)
            $timeout.cancel(resizeTimeout)
            resizeTimeout = null

          resizeTimeout = $timeout ->
            elem.parent().css(overflow: '')
            width = getElemWidth()
            handleWidth = width * getModelWidth()
            svg.attr('width', width)
            scrollbarBG.attr('width', width)
            scrollbarHandle.attr('width', handleWidth)
            updateMargin(getModelValue() * (width - handleWidth))
            resizeTimeout = null
          , 100

        # end init

      getModelValue = ->
        ngModel.$viewValue?.value || 0

      getModelWidth = ->
        ngModel.$viewValue?.width || 1

      getMarginLeft = ->
        scrollbarHandle.attr('x') * 1

      getElemWidth = ->
        elem.width()

      getScrollBarWidth = ->
        scrollbarHandle.attr('width') * 1

      getSpaceWidth = ->
        getElemWidth() - getScrollBarWidth()

      updateMargin = (newMargin) ->
        spaceWidth = getSpaceWidth()
        if newMargin > spaceWidth then newMargin = spaceWidth
        if newMargin < 0 then newMargin = 0
        scrollbarHandle.attr('x', newMargin)

      $timeout(init, 2000)


]
