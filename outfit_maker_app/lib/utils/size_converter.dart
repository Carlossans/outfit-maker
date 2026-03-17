class SizeConverter {
  static String euToUs(String eu) {
    switch (eu) {
      case "38":
        return "6";

      case "40":
        return "8";

      case "42":
        return "10";

      default:
        return eu;
    }
  }
}
