﻿using Microsoft.Owin.Security.ActiveDirectory;
using Owin;
using System.Configuration;
using System.IdentityModel.Tokens;

namespace TodoListWebApi
{
    public partial class Startup
    {
        public void ConfigureAuth(IAppBuilder app)
        {
            app.UseWindowsAzureActiveDirectoryBearerAuthentication(new WindowsAzureActiveDirectoryBearerAuthenticationOptions
                {
                    TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidAudience = SiteConfiguration.TodoListWebApiResourceId,
                        SaveSigninToken = true // This places the original token on the ClaimsIdentity.BootstrapContext.
                    },
                    Tenant = SiteConfiguration.AadTenant
                });
        }
    }
}