const Set<String> kImageExts = {
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif', 'tiff',
};
const Set<String> kVideoExts = {'mp4', 'mov', 'mkv', 'avi', 'webm', '3gp', 'm4v'};

bool isMediaFile(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return false;
  final ext = fileName.substring(dot + 1).toLowerCase();
  return kImageExts.contains(ext) || kVideoExts.contains(ext);
}
