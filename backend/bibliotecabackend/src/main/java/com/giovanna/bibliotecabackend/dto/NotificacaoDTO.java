package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Notificacao;

import java.time.LocalDateTime;

public record NotificacaoDTO(
        Long id,
        String tipo,
        String conteudo,
        boolean lida,
        Long dadoId,
        String dadoNome,
        String fotoUrl,
        Long autorId,
        String autorNome,
        String autorFotoUrl,
        LocalDateTime dataCriacao
) {
    public static NotificacaoDTO fromEntity(Notificacao n) {
        Long autorId = null;
        String autorNome = null;
        String autorFotoUrl = null;
        if (n.getAutor() != null) {
            autorId = n.getAutor().getId();
            autorNome = n.getAutor().getNome();
            autorFotoUrl = n.getAutor().getFotoPerfil();
        }
        return new NotificacaoDTO(
            n.getId(),
            n.getTipo() != null ? n.getTipo().name() : null,
            n.getConteudo(),
            n.isLida(),
            n.getDadoId(),
            n.getDadoNome(),
            n.getFotoUrl(),
            autorId,
            autorNome,
            autorFotoUrl,
            n.getDataCriacao()
        );
    }
}
