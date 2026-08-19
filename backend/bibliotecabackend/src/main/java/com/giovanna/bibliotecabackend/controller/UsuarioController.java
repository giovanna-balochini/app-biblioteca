package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.AvaliacaoPublicaDTO;
import com.giovanna.bibliotecabackend.dto.PublicUserProfileDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Seguidor;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.service.SeguidorService;
import com.giovanna.bibliotecabackend.service.UsuarioService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/usuarios")
@RequiredArgsConstructor
public class UsuarioController {

    private final UsuarioService usuarioService;
    private final SeguidorService seguidorService;

    @GetMapping
    public List<Usuario> listarTodos() {
        return usuarioService.listarTodos();
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> buscarPorId(@PathVariable Long id) {
        return usuarioService.obterPerfilPublico(id)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/avaliacoes")
    public ResponseEntity<Map<String, Object>> listarAvaliacoesDoUsuario(
            @PathVariable Long id,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        if (!usuarioService.buscarPorId(id).isPresent()) {
            return ResponseEntity.notFound().build();
        }
        Page<Avaliacao> pagina = usuarioService.listarAvaliacoesPublicasDoUsuario(id, page, size);
        List<AvaliacaoPublicaDTO> itens = pagina.getContent().stream()
                .map(AvaliacaoPublicaDTO::fromEntity)
                .collect(Collectors.toList());

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("pagina", pagina.getNumber());
        resposta.put("tamanhoPagina", pagina.getSize());
        resposta.put("totalElementos", pagina.getTotalElements());
        resposta.put("totalPaginas", pagina.getTotalPages());
        resposta.put("ultima", pagina.isLast());
        resposta.put("itens", itens);
        return ResponseEntity.ok(resposta);
    }

    @PostMapping("/{id}/seguir")
    public ResponseEntity<?> seguir(@PathVariable Long id) {
        try {
            Seguidor s = seguidorService.seguir(id);
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("ok", true);
            r.put("accao", "seguindo");
            r.put("totalSeguidores", seguidorService.totalSeguidores(
                    usuarioService.buscarPorId(id).orElse(null)));
            return ResponseEntity.status(HttpStatus.CREATED).body(r);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("erro", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}/seguir")
    public ResponseEntity<?> desseguir(@PathVariable Long id) {
        try {
            seguidorService.desseguir(id);
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("ok", true);
            r.put("accao", "desseguido");
            r.put("totalSeguidores", seguidorService.totalSeguidores(
                    usuarioService.buscarPorId(id).orElse(null)));
            return ResponseEntity.ok(r);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("erro", e.getMessage()));
        }
    }

    @GetMapping("/{id}/seguidores")
    public ResponseEntity<?> listarSeguidores(
            @PathVariable Long id,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return usuarioService.buscarPorId(id)
                .map(alvo -> {
                    Page<PublicUserProfileDTO> pagina = seguidorService.listarSeguidoresPaginado(alvo, page, size);
                    Map<String, Object> resposta = new LinkedHashMap<>();
                    resposta.put("pagina", pagina.getNumber());
                    resposta.put("tamanhoPagina", pagina.getSize());
                    resposta.put("totalElementos", pagina.getTotalElements());
                    resposta.put("totalPaginas", pagina.getTotalPages());
                    resposta.put("ultima", pagina.isLast());
                    resposta.put("itens", pagina.getContent());
                    return ResponseEntity.ok((Object) resposta);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/seguindo")
    public ResponseEntity<?> listarSeguindo(
            @PathVariable Long id,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return usuarioService.buscarPorId(id)
                .map(alvo -> {
                    Page<PublicUserProfileDTO> pagina = seguidorService.listarSeguindoPaginado(alvo, page, size);
                    Map<String, Object> resposta = new LinkedHashMap<>();
                    resposta.put("pagina", pagina.getNumber());
                    resposta.put("tamanhoPagina", pagina.getSize());
                    resposta.put("totalElementos", pagina.getTotalElements());
                    resposta.put("totalPaginas", pagina.getTotalPages());
                    resposta.put("ultima", pagina.isLast());
                    resposta.put("itens", pagina.getContent());
                    return ResponseEntity.ok((Object) resposta);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<?> salvar(@RequestBody Usuario usuario) {
        if (usuarioService.existePorEmail(usuario.getEmail())) {
            return ResponseEntity.badRequest().body("E-mail já cadastrado");
        }
        return ResponseEntity.ok(usuarioService.salvar(usuario));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Usuario> atualizar(@PathVariable Long id, @RequestBody Usuario usuario) {
        return usuarioService.buscarPorId(id)
                .map(usuarioExistente -> {
                    usuario.setId(id);
                    return ResponseEntity.ok(usuarioService.salvar(usuario));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletar(@PathVariable Long id) {
        return usuarioService.buscarPorId(id)
                .map(usuario -> {
                    usuarioService.deletar(id);
                    return ResponseEntity.ok().<Void>build();
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
