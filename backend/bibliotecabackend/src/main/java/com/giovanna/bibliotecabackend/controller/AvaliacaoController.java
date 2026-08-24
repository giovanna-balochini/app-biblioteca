package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.AvaliacaoPublicaDTO;
import com.giovanna.bibliotecabackend.dto.AvaliacaoRequest;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.service.AvaliacaoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/livros/{livroId}/avaliacoes")
@RequiredArgsConstructor
public class AvaliacaoController {

    private final AvaliacaoService avaliacaoService;

    @GetMapping
    public ResponseEntity<Map<String, Object>> listar(@PathVariable Long livroId) {
        try {
            List<AvaliacaoPublicaDTO> dtos = avaliacaoService.listarPorLivroDTO(livroId);
            Double media = avaliacaoService.mediaPorLivro(livroId);
            Map<String, Object> resposta = new LinkedHashMap<>();
            resposta.put("media", media);
            resposta.put("total", dtos.size());
            resposta.put("avaliacoes", dtos);
            return ResponseEntity.ok(resposta);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping
    public ResponseEntity<?> publicar(@PathVariable Long livroId, @RequestBody AvaliacaoRequest request) {
        try {
            LocalDate data = null;
            if (request.getDataConclusao() != null && !request.getDataConclusao().isBlank()) {
                try {
                    data = LocalDate.parse(request.getDataConclusao());
                } catch (DateTimeParseException e) {
                    return ResponseEntity.badRequest().body("dataConclusao deve estar no formato yyyy-MM-dd");
                }
            }
            Avaliacao salvo = avaliacaoService.publicarOuAtualizar(
                    livroId,
                    request.getNota(),
                    request.getComentario(),
                    data
            );
            return ResponseEntity.status(HttpStatus.CREATED).body(avaliacaoService.aplicarCurtidas(salvo));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}
