﻿'use strict';
angular.module('todoApp')
.factory('categorySvc', ['$http', 'config', function ($http, config) {
    return {
        getItems: function () {
            // [NOTE] The bearer token is automatically attached by ADAL.JS,
            // no additional HTTP handling is necessary here.
            return $http.get(config.todoListWebApiRootUrl + 'api/category');
        },
        postItem: function (item) {
            return $http.post(config.todoListWebApiRootUrl + 'api/category', item);
        }
    };
}]);