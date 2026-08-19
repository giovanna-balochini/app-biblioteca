package com.giovanna.bibliotecabackend.controller;

import com.giovanna.bibliotecabackend.dto.FeedItemDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.service.AvaliacaoService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/feed")
@RequiredArgsConstructor
public class FeedController {

    private final AvaliacaoService avaliacaoService;

    @GetMapping
    public Map<String, Object> listarFeed(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "") String filtro
    ) {
        Page<Avaliacao> pagina = avaliacaoService.listarFeed(page, size, filtro);
        List<FeedItemDTO> itens = pagina.getContent().stream()
                .map(FeedItemDTO::fromEntity)
                .collect(Collectors.toList());

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("pagina", pagina.getNumber());
        resposta.put("tamanhoPagina", pagina.getSize());
        resposta.put("totalElementos", pagina.getTotalElements());
        resposta.put("totalPaginas", pagina.getTotalPages());
        resposta.put("ultima", pagina.isLast());
        resposta.put("filtro", (filtro == null || filtro.isBlank()) ? "todos" : filtro.toLowerCase());
        resposta.put("itens", itens);
        return resposta;
    }
}
