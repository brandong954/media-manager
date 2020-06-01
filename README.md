# Media Manager

## Summary
Separates and organizes videos and pictures exported from Apple's Photos.app into `year/month/moment` directories.

## Usage
Run `media_manager.sh $SOURCE_DIRECTORY [$PICTURES_BACKUP_DIRECTORY] [$VIDEOS_BACKUP_DIRECTORY]`.

The `SOURCE_DIRECTORY` is the directory containing the exported media files from Photos.app.
  - When exporting from Photos.app, make sure "Subfolder Format" is set to "Moment Name."

By default, `PICTURES_BACKUP_DIRECTORY` and `VIDEOS_BACKUP_DIRECTORY` directory will be `./BACKUP`.

This script uses `mv` commands to sort and backup files, so it is recommended to have `SOURCE_DIRECTORY` reside on the same drive as `PICTURES_BACKUP_DIRECTORY` and `VIDEOS_BACKUP_DIRECTORY` for optimal performance.

You'll also need to update your various device names within `determine_media_device_source()`.

As a good rule of thumb with anything, test this script on a subset of copied files to make sure you get the desired output you're looking for before doing the whole shibang.

You might also need to update `PICTURE_EXTENSIONS` and `VIDEO_EXTENSIONS` to contain any unforseen filetypes. Just run the script again, and they should be handled correctly.
