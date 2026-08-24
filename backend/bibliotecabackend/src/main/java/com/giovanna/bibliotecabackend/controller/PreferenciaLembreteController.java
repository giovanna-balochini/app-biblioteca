package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.PreferenciaLembreteDTO;
import com.giovanna.bibliotecabackend.service.PreferenciaLembreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/lembrete")
@RequiredArgsConstructor
public class PreferenciaLembreteController {

    private final PreferenciaLembreteService service;

    @GetMapping("/preferencias")
    public ResponseEntity<PreferenciaLembreteDTO> buscarPreferencias() {
        return ResponseEntity.ok(service.buscarOuCriarPadrao());
    }

    @PutMapping("/preferencias")
    public ResponseEntity<PreferenciaLembreteDTO> salvarPreferencias(@RequestBody PreferenciaLembreteDTO dto) {
        return ResponseEntity.ok(service.salvar(dto));
    }
}
