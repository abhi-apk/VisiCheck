import "package:flutter/material.dart";

class MyTextField extends StatelessWidget {
  final controller;
  final String hintText;
  final bool obscureText;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                  color: Color.fromRGBO(141, 188, 252, 1), width: 6),
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Color.fromRGBO(141, 188, 252, 1),
              ),
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            fillColor: Color.fromRGBO(141, 188, 252, 1),
            filled: true,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Color.fromRGBO(80, 72, 82, 1),
              
              fontSize: 15,
              // fontWeight: FontWeight.bold
            )),
      ),
    );
  }
}
