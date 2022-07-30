# VisualStudioNugetPushFix

Working publish command for the visual studio artifact feed.

## About

This module is to allow publishing to authenticated nuget feeds.
As of the writing of this module, powershell's nuget implementation does not allow publishing to authenticated nuget v2 without workarounds or to v3 feeds at all.
This module implements the API for the nuget feed directly instead of using nuget.exe or nuget.*.dll libraries.

This module only deals with publishing modules. For installing modules, you should still use the PowershellGet preview 3.0 or newer module which does support installing from a v3 feed.

## Commands

### Publish-VisualStudioNuGetV3FeedFile

Publish a file to a nuget feed.
This should work for the artifact feeds that are hosted on visualstudio.com.
It might also work for other feeds such as github, but they are not a test target at the moment.

## Author

PurpleMonkeyMad  
github.com/purplemonkeymad  
/u/purplemonkemad