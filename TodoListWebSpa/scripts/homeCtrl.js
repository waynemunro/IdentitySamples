﻿'use strict';
angular.module('todoApp')
.controller('homeCtrl', ['$scope', 'config', 'adalAuthenticationService', '$location', function ($scope, config, adalService, $location) {
    $scope.applicationName = config.ApplicationName;
    $scope.signin = function () {
        adalService.login(); // [NOTE] This explicitly triggers a sign-in.
    };
    $scope.canSignout = config.StsSupportsLogOut;
    $scope.signout = function () {
        adalService.logOut(); // [NOTE] This explicitly triggers a sign-out.
    };
    $scope.isActive = function (viewLocation) {
        return viewLocation === $location.path();
    };
}]);