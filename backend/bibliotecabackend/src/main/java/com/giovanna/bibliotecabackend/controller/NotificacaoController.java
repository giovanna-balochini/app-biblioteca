package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.NotificacaoDTO;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import com.giovanna.bibliotecabackend.service.NotificacaoService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/notificacoes")
@RequiredArgsConstructor
public class NotificacaoController {

    private final NotificacaoService notificacaoService;
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

    @GetMapping
    public ResponseEntity<Map<String, Object>> listarMinhas(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        if (page < 0) page = 0;
        if (size < 1 || size > 100) size = 20;

        Page<NotificacaoDTO> pagina = notificacaoService.listarMinhasPaginado(page, size, usuarioId);
        long naoLidas = notificacaoService.contarNaoLidas(usuarioId);

        Map<String, Object> resposta = new HashMap<>();
        resposta.put("itens", pagina.getContent());
        resposta.put("pagina", pagina.getNumber());
        resposta.put("tamanho", pagina.getSize());
        resposta.put("totalItens", pagina.getTotalElements());
        resposta.put("totalPaginas", pagina.getTotalPages());
        resposta.put("ultima", pagina.isLast());
        resposta.put("naoLidas", naoLidas);
        return ResponseEntity.ok(resposta);
    }

    @GetMapping("/contagem-nao-lidas")
    public ResponseEntity<Map<String, Object>> contagemNaoLidas() {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        long qtde = notificacaoService.contarNaoLidas(usuarioId);
        Map<String, Object> resposta = new HashMap<>();
        resposta.put("naoLidas", qtde);
        return ResponseEntity.ok(resposta);
    }

    @PatchMapping("/lidas")
    public ResponseEntity<Map<String, Object>> marcarTodasComoLidas() {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        long marcadas = notificacaoService.marcarTodasComoLidas(usuarioId);
        Map<String, Object> resposta = new HashMap<>();
        resposta.put("ok", true);
        resposta.put("marcadas", marcadas);
        return ResponseEntity.ok(resposta);
    }

    @PatchMapping("/{id}/lida")
    public ResponseEntity<Map<String, Object>> marcarUmaComoLida(@PathVariable Long id) {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        boolean ok = notificacaoService.marcarUmaComoLida(id, usuarioId);
        if (!ok) return ResponseEntity.notFound().build();
        Map<String, Object> resposta = new HashMap<>();
        resposta.put("ok", true);
        return ResponseEntity.ok(resposta);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> excluirUma(@PathVariable Long id) {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        boolean ok = notificacaoService.excluir(id, usuarioId);
        if (!ok) return ResponseEntity.notFound().build();
        Map<String, Object> resposta = new HashMap<>();
        resposta.put("ok", true);
        return ResponseEntity.ok(resposta);
    }

    @DeleteMapping
    public ResponseEntity<Map<String, Object>> limparTodas() {
        Long usuarioId = obterUsuarioAutenticadoId();
        if (usuarioId == null) return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        long removidas = notificacaoService.limparTodas(usuarioId);
        Map<String, Object> resposta = new HashMap<>();
        resposta.put("ok", true);
        resposta.put("removidas", removidas);
        return ResponseEntity.ok(resposta);
    }
}
