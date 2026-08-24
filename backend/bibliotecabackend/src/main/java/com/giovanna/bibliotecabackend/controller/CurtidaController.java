package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.service.CurtidaService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/avaliacoes")
@RequiredArgsConstructor
public class CurtidaController {

    private final CurtidaService curtidaService;

    @PostMapping("/{avaliacaoId}/curtir")
    public ResponseEntity<Map<String, Object>> curtir(@PathVariable Long avaliacaoId) {
        try {
            Map<String, Object> r = curtidaService.toggleCurtida(avaliacaoId);
            boolean curti = Boolean.TRUE.equals(r.get("curti"));
            return ResponseEntity.status(curti ? HttpStatus.CREATED : HttpStatus.OK).body(r);
        } catch (IllegalArgumentException e) {
            Map<String, Object> erro = new HashMap<>();
            erro.put("ok", false);
            erro.put("erro", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(erro);
        } catch (Exception e) {
            Map<String, Object> erro = new HashMap<>();
            erro.put("ok", false);
            erro.put("erro", "Falha ao processar curtida");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(erro);
        }
    }

    @DeleteMapping("/{avaliacaoId}/curtir")
    public ResponseEntity<Map<String, Object>> descurtir(@PathVariable Long avaliacaoId) {
        return curtir(avaliacaoId);
    }
}
