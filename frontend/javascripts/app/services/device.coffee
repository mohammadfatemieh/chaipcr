window.App.service 'Device', [
  '$http'
  '$q'
  'host'
  'Upload'
  'Status'
  '$uibModal'
  ($http, $q, host, Upload, Status, $uibModal) ->

    class Device

      version_info = null
      is_offline = false
      capabilities = null
      @direct_upload = false

      isOffline: -> is_offline

      getCapabilities: ->
        deferred = $q.defer()
        if capabilities isnt null
          deferred.resolve capabilities
        else
          $http.get('/capabilities').then (resp) ->
            capabilities = resp
            deferred.resolve resp

        return deferred.promise

      isDualChannel: ->
        deferred = $q.defer()
        @getCapabilities().then (resp) ->
          deferred.resolve resp.data.capabilities?.optics?.emission_channels?.length is 2
        return deferred.promise

      channelCount: ->
        deferred = $q.defer()
        @getCapabilities().then (resp) ->
          deferred.resolve resp.data.capabilities?.optics?.emission_channels?.length || 1
        return deferred.promise

      checkForUpdate: ->
        @direct_upload = false
        checkCloudUpdate = (deferred) =>
          cloudCheckPromise = $http.get("http://update.chaibio.com/device/software_update")
          cloudCheckPromise.then (resp) =>
            cloudInfo = resp.data
            deviceCheckPromise = @getVersion()
            deviceCheckPromise.then (device) ->
              is_offline = true
              if cloudInfo.software_version isnt device.software?.version
                deferred.resolve 'available'
              else
                deferred.resolve 'unavailable'

            deviceCheckPromise.catch ->
              deferred.reject()

          cloudCheckPromise.catch ->
            deferred.reject()

        deferred = $q.defer()
        localCheckPromise = $http.post("#{host}\:8000/device/check_for_updates")
        localCheckPromise.then (resp) ->

          status = resp?.data?.device?.update_available || 'unknown'

          if status is 'unknown'
            Status.fetch()
            .then (resp) ->
              status = resp?.device?.update_available || 'unknown'
              if status is 'unknown'
                is_offline = true
                checkCloudUpdate deferred
              else
                is_offline = false
                deferred.resolve status
            .catch ->
              checkCloudUpdate deferred
          else
            deferred.resolve status

        localCheckPromise.catch =>
          is_offline = true
          checkCloudUpdate deferred

        deferred.promise

      getUpdateInfo: ->
        checkCloudInfo = (deferred) ->
          cloudPromise = $http.get("http://update.chaibio.com/device/software_update")
          cloudPromise.then (resp) ->
            deferred.resolve resp.data
          cloudPromise.catch (err) ->
            deferred.reject err

        deferred = $q.defer()

        Status.fetch()
        .then (resp) ->
          status = resp?.device?.update_available || 'unknown'
          if status is 'unknown'
            checkCloudInfo deferred
          else
            infoPromise = $http.get('/device/software_update')
            infoPromise.then (resp) =>
              if resp.data?.upgrade
                deferred.resolve resp.data.upgrade
              else
                checkCloudInfo deferred
            infoPromise.catch (err) ->
              checkCloudInfo deferred
        .catch ->
          checkCloudInfo deferred

        deferred.promise

      getVersion: (cache = false) ->
        deferred = $q.defer()
        if cache and version_info
          deferred.resolve version_info
        else
          promise = $http.get('/device')
          promise.then (resp) ->
            version_info = resp.data
            deferred.resolve resp.data
          promise.catch (resp) ->
            deferred.reject resp

        return deferred.promise

      openUploadModal: ->
        @direct_upload = true;
        $uibModal.open
          templateUrl: 'app/views/settings/modal-software-update.html'
          controller: 'SoftwareUpdateCtrl'
          openedClass: 'modal-software-update-open'
          keyboard: false
          backdrop: 'static'

      openUpdateModal: ->
        @direct_upload = false
        $uibModal.open
          templateUrl: 'app/views/settings/modal-software-update.html'
          controller: 'SoftwareUpdateCtrl'
          openedClass: 'modal-software-update-open'
          keyboard: false
          backdrop: 'static'

      updateSoftware: ->
        return $http.post("#{host}\:8000/device/update_software")

      uploadImage: (file) ->
        Upload.upload
          url: "#{host}\:8000/device/upload_software_update"
          method: 'POST'
          'Content-Type': 'multipart/form-data'
          data:
            upgradefile: file

    return new Device

]
