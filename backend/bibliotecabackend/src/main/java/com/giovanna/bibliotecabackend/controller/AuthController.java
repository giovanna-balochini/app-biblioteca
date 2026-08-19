package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.AuthResponse;
import com.giovanna.bibliotecabackend.dto.LoginRequest;
import com.giovanna.bibliotecabackend.dto.RegistroRequest;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import com.giovanna.bibliotecabackend.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UsuarioRepository usuarioRepository;
    private final JwtService jwtService;

    @PostMapping("/registrar")
    public ResponseEntity<?> registrar(@RequestBody RegistroRequest request) {
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            return ResponseEntity.badRequest().body("E-mail é obrigatório");
        }
        if (request.getSenha() == null || request.getSenha().length() < 6) {
            return ResponseEntity.badRequest().body("Senha deve ter pelo menos 6 caracteres");
        }
        if (usuarioRepository.existsByEmail(request.getEmail())) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body("E-mail já cadastrado");
        }

        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        Usuario usuario = new Usuario();
        usuario.setNome(request.getNome() != null ? request.getNome() : request.getEmail());
        usuario.setEmail(request.getEmail());
        usuario.setSenha(encoder.encode(request.getSenha()));
        Usuario salvo = usuarioRepository.save(usuario);

        String token = jwtService.gerarToken(salvo.getEmail());
        return ResponseEntity.ok(new AuthResponse(token, salvo.getId(), salvo.getEmail(), salvo.getNome()));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        if (request.getEmail() == null || request.getSenha() == null) {
            return ResponseEntity.badRequest().body("E-mail e senha são obrigatórios");
        }

        Usuario usuario = usuarioRepository.findByEmail(request.getEmail()).orElse(null);
        if (usuario == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("E-mail ou senha inválidos");
        }

        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        String senhaArmazenada = usuario.getSenha();
        boolean senhaCorreta = false;
        boolean precisaReHash = false;

        if (senhaArmazenada != null && senhaArmazenada.startsWith("$2a$")) {
            try {
                senhaCorreta = encoder.matches(request.getSenha(), senhaArmazenada);
            } catch (Exception ignored) {}
        }

        if (!senhaCorreta && senhaArmazenada != null && senhaArmazenada.equals(request.getSenha())) {
            senhaCorreta = true;
            precisaReHash = true;
        }

        if (!senhaCorreta) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("E-mail ou senha inválidos");
        }

        if (precisaReHash) {
            usuario.setSenha(encoder.encode(request.getSenha()));
            usuarioRepository.save(usuario);
        }

        String token = jwtService.gerarToken(usuario.getEmail());
        return ResponseEntity.ok(new AuthResponse(token, usuario.getId(), usuario.getEmail(), usuario.getNome()));
    }
}
