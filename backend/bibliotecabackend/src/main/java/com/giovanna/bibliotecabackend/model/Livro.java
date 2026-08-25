package com.giovanna.bibliotecabackend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDate;

@Data
@Entity
@Table(name = "livro")
public class Livro {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String titulo;
    private String autor;
    private String editora;
    private String genero;
    @Column(length = 500)
    private String descricao;
    private String imagem;

    @Deprecated
    @Column(name = "lido_legado")
    private boolean lido;

    @Enumerated(EnumType.STRING)
    @Column(name = "status_leitura", length = 20)
    private StatusLeitura statusLeitura;

    @Column(name = "pagina_atual")
    private Integer paginaAtual;

    @Column(name = "total_paginas")
    private Integer totalPaginas;

    @Column(name = "data_inicio_leitura")
    private LocalDate dataInicioLeitura;

    @Column(name = "data_fim_leitura")
    private LocalDate dataFimLeitura;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id")
    private Usuario dono;

    @PrePersist
    protected void aoCriar() {
        sincronizarStatusLegado();
    }

    @PreUpdate
    protected void aoAtualizar() {
        sincronizarStatusLegado();
    }

    private void sincronizarStatusLegado() {
        if (statusLeitura == null) {
            statusLeitura = lido ? StatusLeitura.LIDO : StatusLeitura.QUERO_LER;
        }
        lido = StatusLeitura.LIDO.equals(statusLeitura);
        if (paginaAtual != null && paginaAtual < 0) paginaAtual = 0;
        if (totalPaginas != null && totalPaginas < 0) totalPaginas = null;
        if (paginaAtual != null && totalPaginas != null && paginaAtual > totalPaginas) {
            paginaAtual = totalPaginas;
        }
    }

    public double getProgressoPercentual() {
        if (totalPaginas == null || totalPaginas <= 0 || paginaAtual == null) return 0.0;
        double p = (paginaAtual * 100.0) / totalPaginas;
        if (p < 0) p = 0;
        if (p > 100) p = 100;
        return Math.round(p * 10.0) / 10.0;
    }

    public boolean isLido() {
        return StatusLeitura.LIDO.equals(statusLeitura);
    }

    public void setLido(boolean l) {
        this.lido = l;
        if (l && !StatusLeitura.LIDO.equals(this.statusLeitura)) {
            setStatusLeitura(StatusLeitura.LIDO);
        } else if (!l && StatusLeitura.LIDO.equals(this.statusLeitura)) {
            if (paginaAtual != null && paginaAtual > 0) {
                setStatusLeitura(StatusLeitura.LENDO);
            } else {
                setStatusLeitura(StatusLeitura.QUERO_LER);
            }
        }
    }
}
