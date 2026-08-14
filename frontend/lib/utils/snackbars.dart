import 'package:flutter/material.dart';

const Color _corPrimaria = Color(0xFF7C4DFF);
const Color _corSucesso = Color(0xFF2E7D32);
const Color _corErro = Color(0xFFC62828);
const Color _corAviso = Color(0xFFEF6C00);
const Color _corTextoClaro = Colors.white;
const Color _corFundo = Color(0xFFF5F0FF);
const Color _corTextoEscuro = Color(0xFF1A1033);

SnackBar _buildSnackBar({
  required String mensagem,
  required Color corFundo,
  required Color corTexto,
  Color? corIcone,
  required IconData icone,
}) {
  return SnackBar(
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icone,
          color: corIcone ?? corTexto,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mensagem,
            style: TextStyle(
              color: corTexto,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
    backgroundColor: corFundo,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    duration: const Duration(seconds: 3),
    elevation: 6,
    action: SnackBarAction(
      label: 'Ok',
      textColor: corTexto,
      onPressed: () {},
    ),
  );
}

void mostrarSnackbarSucesso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      _buildSnackBar(
        mensagem: mensagem,
        corFundo: _corSucesso,
        corTexto: _corTextoClaro,
        icone: Icons.check_circle_outline_rounded,
      ),
    );
}

void mostrarSnackbarErro(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      _buildSnackBar(
        mensagem: mensagem,
        corFundo: _corErro,
        corTexto: _corTextoClaro,
        icone: Icons.error_outline_rounded,
      ),
    );
}

void mostrarSnackbarAviso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      _buildSnackBar(
        mensagem: mensagem,
        corFundo: _corAviso,
        corTexto: _corTextoClaro,
        icone: Icons.warning_amber_rounded,
      ),
    );
}

void mostrarSnackbarInfo(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      _buildSnackBar(
        mensagem: mensagem,
        corFundo: _corFundo,
        corTexto: _corTextoEscuro,
        corIcone: _corPrimaria,
        icone: Icons.info_outline_rounded,
      ),
    );
}
