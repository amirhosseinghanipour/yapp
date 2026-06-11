class Attachment {
  const Attachment({
    this.objectKey,
    this.blobKey,
    this.nonce,
    this.size,
    this.mime,
    this.fileName,
    this.width,
    this.height,
    this.durationMs,
    this.lat,
    this.lng,
  });

  final String? objectKey;
  final String? blobKey;
  final String? nonce;
  final int? size;
  final String? mime;
  final String? fileName;
  final int? width;
  final int? height;
  final int? durationMs;
  final double? lat;
  final double? lng;

  bool get hasBlob => objectKey != null && blobKey != null && nonce != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (objectKey != null) 'objectKey': objectKey,
    if (blobKey != null) 'key': blobKey,
    if (nonce != null) 'nonce': nonce,
    if (size != null) 'size': size,
    if (mime != null) 'mime': mime,
    if (fileName != null) 'fileName': fileName,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (durationMs != null) 'durationMs': durationMs,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };

  static Attachment fromJson(Map<String, dynamic> j) => Attachment(
    objectKey: j['objectKey'] as String?,
    blobKey: j['key'] as String?,
    nonce: j['nonce'] as String?,
    size: (j['size'] as num?)?.toInt(),
    mime: j['mime'] as String?,
    fileName: j['fileName'] as String?,
    width: (j['width'] as num?)?.toInt(),
    height: (j['height'] as num?)?.toInt(),
    durationMs: (j['durationMs'] as num?)?.toInt(),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );
}
