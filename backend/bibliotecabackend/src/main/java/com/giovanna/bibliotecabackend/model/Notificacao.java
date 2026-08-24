package com.giovanna.bibliotecabackend.model;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "notificacao", indexes = {
    @Index(name = "idx_notificacao_usuario_data", columnList = "usuario_id, dataCriacao DESC")
})
public class Notificacao {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TipoNotificacao tipo;

    @Column(nullable = false, length = 255)
    private String conteudo;

    @Column(name = "dado_id")
    private Long dadoId;

    @Column(length = 120)
    private String dadoNome;

    @Column(name = "foto_url", length = 500)
    private String fotoUrl;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "autor_id")
    private Usuario autor;

    @Column(nullable = false)
    private boolean lida = false;

    @Column(name = "dataCriacao", nullable = false, updatable = false)
    private LocalDateTime dataCriacao;

    public enum TipoNotificacao {
        SEGUIR,
        AVALIACAO,
        CURTIDA,
        MENSAGEM
    }

    @PrePersist
    protected void preencherData() {
        if (dataCriacao == null) dataCriacao = LocalDateTime.now();
    }
}
