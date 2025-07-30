abstract interface class Serializable {
  /// Converts the object to a JSON string representation.
  /// This method should be implemented by all classes that mixin Serializable.
  String toJson();

  /// Creates an object from a JSON string representation.
  /// This method should be implemented by all classes that mixin Serializable.
  Serializable.fromJson(String json);

  /// Converts the object to a map representation.
  /// This method is useful for converting the object to a format that can be
  /// easily serialized or stored.
  Map<String, dynamic> toMap();

  /// Creates an object from a map representation.
  /// This method is useful for converting the object from a format that can be
  /// easily serialized or stored.
  Serializable.fromMap(Map<String, dynamic> map);
}
