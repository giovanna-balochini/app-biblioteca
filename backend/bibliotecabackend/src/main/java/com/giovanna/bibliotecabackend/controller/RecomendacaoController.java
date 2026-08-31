package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.RecomendacaoResponseDTO;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import com.giovanna.bibliotecabackend.service.RecomendacaoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/recomendacoes")
@RequiredArgsConstructor
public class RecomendacaoController {

    private final RecomendacaoService recomendacaoService;
    private final UsuarioRepository usuarioRepository;

    private Long obterUsuarioAutenticadoId() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof Usuario u && u.getId() != null) {
                return u.getId();
            }
        } catch (Exception ignored) {}
        String email = null;
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated()) email = auth.getName();
        } catch (Exception ignored) {}
        if (email != null) {
            return usuarioRepository.findByEmail(email).map(Usuario::getId).orElse(null);
        }
        return usuarioRepository.findByEmail("u...@exemplo.com").map(Usuario::getId).orElse(null);
    }

    @GetMapping("/para-mim")
    public ResponseEntity<Map<String, Object>> paraMim(
            @RequestParam(defaultValue = "12") int limite
    ) {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        if (limite < 1) limite = 5;
        if (limite > 30) limite = 20;

        final int limiteFinal = limite;
        Usuario eu = usuarioRepository.findById(usuarioId).orElse(null);
        if (eu == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();

        List<RecomendacaoResponseDTO> lista = recomendacaoService.gerarRecomendacoesPara(eu);
        if (lista.size() > limiteFinal) lista = lista.subList(0, limiteFinal);

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("itens", lista);
        resposta.put("quantidade", lista.size());
        resposta.put("baseadoEm", lista.isEmpty() ? "populares-da-comunidade" : "seu-historico-de-leitura");
        return ResponseEntity.ok(resposta);
    }
}
