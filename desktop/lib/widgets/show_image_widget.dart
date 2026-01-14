import 'package:flutter/material.dart';
import '../utils/image_helper.dart';

/// Reusable widget za prikaz slike predstave sa fallback logikom
class ShowImageWidget extends StatelessWidget {
  final String? imagePath;
  final String? institutionImagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ShowImageWidget({
    super.key,
    this.imagePath,
    this.institutionImagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = ImageHelper.getImageUrl(
      imagePath: imagePath,
      institutionImagePath: institutionImagePath,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return placeholder ??
                Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                Container(
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.image_not_supported,
                    size: (height ?? 100) * 0.5,
                    color: Colors.grey[600],
                  ),
                );
          },
        ),
      ),
    );
  }
}
