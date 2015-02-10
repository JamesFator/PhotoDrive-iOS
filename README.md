# Photo Drive iOS
## Sync your photos straight to Google Drive

The current way Google has automatic photo backup is through the Google+ app
and when on a desktop or laptop, you access those photos from your browser.
This iOS app bypasses Google+ entirely and drops your photos straight into
Google Drive. This is beneficial in certain aspects such as the ability to
have your files instantly downloaded to a local hard drive on a machine
that has the Google Drive app installed.

The goal of this was to keep original file formats as well as associated
meta data while allowing an alternative to photo backups with Google.


## Installation

This app is based on the Google APIs Client Library for Objective-C.
[Integration with this library is required and a guide can be found here.](https://developers.google.com/drive/ios/quickstart)

In addition to that, there may be additional tweaking required in the
Xcode Build Setting in order to get the app working with different devices.


## To Do

* Add an interface.
* Background refresh.
* Customizable Google Drive folders to upload into.
* Possibly add additional check to prevent overwriting and duplication.
* See if there's a better way to cache what files were sent.
* Add check and optional switch to only allow upload when on Wi-Fi.
* Optimizations.


## Note

This is still very much a work in progress. If there are any questions,
comments, concerns, or suggestions, [feel free to contact me.](https://github.com/JamesFator)

