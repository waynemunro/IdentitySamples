﻿using Microsoft.Azure.ActiveDirectory.GraphClient;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;

namespace Common
{
    /// <summary>
    /// Provides a wrapper around the <see cref="ActiveDirectoryClient"/>.
    /// </summary>
    public class AadGraphClient
    {
        #region Constants

        /// <summary>
        /// The root endpoint for accessing the Azure Active Directory Graph API.
        /// </summary>
        private const string AadGraphApiEndpoint = "https://graph.windows.net/";

        #endregion

        #region Fields

        private ActiveDirectoryClient client;

        #endregion

        #region Constructors

        /// <summary>
        /// Creates a new <see cref="AadGraphClient"/> instance.
        /// </summary>
        /// <param name="authority">The Azure AD authority representing the tenant.</param>
        /// <param name="tenant">The Azure AD tenant name or identifier.</param>
        /// <param name="clientId">The Client ID of the client application calling the Azure AD Graph API.</param>
        /// <param name="clientSecret">The Client Secret of the client application calling the Azure AD Graph API.</param>
        public AadGraphClient(string authority, string tenant, string clientId, string clientSecret)
        {
            var aadGraphApiTenant = AadGraphApiEndpoint + tenant;
            this.client = new ActiveDirectoryClient(new Uri(aadGraphApiTenant), async () =>
            {
                // [SCENARIO] OAuth 2.0 Client Credential Grant with Client Secret
                // [NOTE] This uses the OAuth 2.0 Client Credentials Grant to authenticate as the client application itself (not as a user).
                var authenticationContext = new AuthenticationContext(authority, false);
                var credential = new ClientCredential(clientId, clientSecret);
                var authenticationResult = await authenticationContext.AcquireTokenAsync(AadGraphApiEndpoint, credential);
                return authenticationResult.AccessToken;
            });
        }

        #endregion

        #region GetGroups

        /// <summary>
        /// Retrieves the Azure AD group details for the requested Group ID's.
        /// </summary>
        /// <param name="groupIds">The Group ID's for which to retrieve the groups.</param>
        /// <returns>The requested groups.</returns>
        public async Task<IList<IGroup>> GetGroupsAsync(IList<string> groupIds)
        {
            // [SCENARIO] Calling the Graph API (Read)
            // There is currently no API to retrieve a filtered list of groups based on their ID's.
            // Alternatives:
            // - Construct the OData query string manually to "OR" together all the requested Group ID's
            // - Retrieve ALL groups and then retain only the requested ones
            // - Retrieve the requested ones individually (via the GetByObjectId method)
            // Here we use the second option to show the client library and how to page through results.
            var groups = new List<IGroup>();
            if (groupIds != null && groupIds.Any())
            {
                // Retrieve the first page of results.
                var groupsResult = await this.client.Groups.ExecuteAsync();
                while (groupsResult != null)
                {
                    // See if any of the requested groups were returned in the current page.
                    var matchingRequestedGroups = groupsResult.CurrentPage.Where(g => groupIds.Any(groupId => string.Equals(groupId, g.ObjectId, StringComparison.OrdinalIgnoreCase)));
                    groups.AddRange(matchingRequestedGroups);

                    if (groupsResult.MorePagesAvailable)
                    {
                        // Keep going while there are more pages.
                        groupsResult = await groupsResult.GetNextPageAsync();
                    }
                    else
                    {
                        break;
                    }
                }
            }
            return groups;
        }

        #endregion

        #region UpdateUser

        /// <summary>
        /// Updates user information.
        /// </summary>
        /// <param name="userObjectId">The Object ID of the user to update.</param>
        /// <param name="displayName">The new display name for the user.</param>
        public async Task UpdateUserAsync(string userObjectId, string displayName)
        {
            // [SCENARIO] Calling the Graph API (Write)
            var user = await this.client.Users.GetByObjectId(userObjectId).ExecuteAsync();
            if (user == null)
            {
                throw new ArgumentException(string.Format(CultureInfo.CurrentCulture, "The user with Object ID \"{0}\" was not found in the directory.", userObjectId));
            }
            user.DisplayName = displayName;
            await user.UpdateAsync();
        }

        #endregion
    }
}