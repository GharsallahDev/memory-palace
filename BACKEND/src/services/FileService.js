// src/services/FileService.js
const fs = require('fs');
const path = require('path');
const ffmpeg = require('ffmpeg-static');
const { exec } = require('child_process');

function runFfmpeg(command) {
  return new Promise((resolve, reject) => {
    exec(`${ffmpeg} ${command}`, (error, stdout, stderr) => {
      if (error) {
        console.error('FFMPEG Error:', stderr);
        return reject(error);
      }
      resolve(stdout);
    });
  });
}

class FileService {
  constructor() {
    this.uploadDir = './uploads';
  }

  async generateVideoThumbnail(videoDbPath) {
    try {
      const fullVideoPath = path.join(this.uploadDir, videoDbPath);

      if (!fs.existsSync(fullVideoPath)) {
        throw new Error(`Video file not found for thumbnail generation: ${fullVideoPath}`);
      }

      const videoDirectory = path.dirname(videoDbPath);
      const videoBasename = path.basename(videoDbPath, path.extname(videoDbPath));

      const thumbnailBasename = `thumb-${videoBasename}.jpg`;
      const fullThumbnailPath = path.join(this.uploadDir, videoDirectory, thumbnailBasename);
      const thumbnailDbPath = path.join(videoDirectory, thumbnailBasename).replace(/\\/g, '/');

      const command = `-i "${fullVideoPath}" -ss 00:00:01.000 -vframes 1 -q:v 2 "${fullThumbnailPath}"`;
      await runFfmpeg(command);

      return thumbnailDbPath;
    } catch (error) {
      console.error('❌ Thumbnail generation error:', error.message);
      return null;
    }
  }

  async deleteFile(fileDbPath) {
    if (!fileDbPath) {
      return false;
    }
    try {
      const fullFilePath = path.join(this.uploadDir, fileDbPath);
      if (fs.existsSync(fullFilePath)) {
        fs.unlinkSync(fullFilePath);
      }
      return true;
    } catch (error) {
      console.error(`❌ File deletion error for ${fileDbPath}:`, error.message);
      return false;
    }
  }
}
module.exports = FileService;