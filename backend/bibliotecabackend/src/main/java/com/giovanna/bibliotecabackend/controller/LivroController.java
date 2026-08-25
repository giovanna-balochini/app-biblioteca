package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.LivroBuscaDTO;
import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.StatusLeitura;
import com.giovanna.bibliotecabackend.service.LivroService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/livros")
@RequiredArgsConstructor
public class LivroController {

    private final LivroService livroService;

    @GetMapping
    public List<Livro> listarTodos() {
        return livroService.listarTodos();
    }

    @GetMapping("/resumo-estante")
    public ResponseEntity<Map<String, Object>> resumoEstante() {
        return ResponseEntity.ok(livroService.resumoEstante());
    }

    @GetMapping("/status/{status}")
    public ResponseEntity<List<Livro>> listarPorStatus(@PathVariable String status) {
        try {
            StatusLeitura s = StatusLeitura.valueOf(status.toUpperCase());
            return ResponseEntity.ok(livroService.listarPorStatus(s));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @GetMapping("/buscar")
    public ResponseEntity<Map<String, Object>> buscarLivros(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Page<LivroBuscaDTO> pagina = livroService.buscarLivros(q, page, size);
        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("pagina", pagina.getNumber());
        resposta.put("tamanhoPagina", pagina.getSize());
        resposta.put("totalElementos", pagina.getTotalElements());
        resposta.put("totalPaginas", pagina.getTotalPages());
        resposta.put("ultima", pagina.isLast());
        resposta.put("itens", pagina.getContent());
        return ResponseEntity.ok(resposta);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Livro> buscarPorId(@PathVariable Long id) {
        return livroService.buscarPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Livro salvar(@RequestBody Livro livro) {
        return livroService.salvar(livro);
    }

    @PostMapping("/{id}/copiar-para-minha-biblioteca")
    public ResponseEntity<Map<String, Object>> copiarParaMinhaBiblioteca(@PathVariable Long id) {
        try {
            Map<String, Object> r = livroService.copiarParaMinhaBiblioteca(id);
            if (Boolean.TRUE.equals(r.get("ok"))) {
                return ResponseEntity.status(HttpStatus.CREATED).body(r);
            }
            return ResponseEntity.ok(r);
        } catch (IllegalArgumentException e) {
            Map<String, Object> erro = new LinkedHashMap<>();
            erro.put("ok", false);
            erro.put("erro", e.getMessage());
            return ResponseEntity.badRequest().body(erro);
        }
    }

    @PatchMapping("/{id}/progresso")
    public ResponseEntity<Livro> atualizarProgresso(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body
    ) {
        Integer paginaAtual = body.containsKey("paginaAtual") && body.get("paginaAtual") != null
                ? ((Number) body.get("paginaAtual")).intValue() : null;
        Integer totalPaginas = body.containsKey("totalPaginas") && body.get("totalPaginas") != null
                ? ((Number) body.get("totalPaginas")).intValue() : null;
        return livroService.atualizarProgresso(id, paginaAtual, totalPaginas)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<Livro> alterarStatus(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body
    ) {
        Object raw = body.get("statusLeitura");
        if (raw == null) return ResponseEntity.badRequest().build();
        try {
            StatusLeitura s = StatusLeitura.valueOf(raw.toString().toUpperCase());
            return livroService.alterarStatus(id, s)
                    .map(ResponseEntity::ok)
                    .orElse(ResponseEntity.notFound().build());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<Livro> atualizar(@PathVariable Long id, @RequestBody Livro livro) {
        return livroService.buscarPorId(id)
                .map(livroExistente -> {
                    livro.setId(id);
                    livro.setDono(livroExistente.getDono());
                    return ResponseEntity.ok(livroService.salvar(livro));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletar(@PathVariable Long id) {
       return livroService.buscarPorId(id)
               .map(livro-> {
                   livroService.deletar(id);
                   return ResponseEntity.ok().<Void>build();
               })
               .orElse(ResponseEntity.notFound().build());
    }
}
