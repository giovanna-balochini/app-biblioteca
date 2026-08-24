package com.giovanna.bibliotecabackend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@Entity
@Table(name = "preferencia_lembrete", uniqueConstraints = {
        @UniqueConstraint(columnNames = "usuario_id")
})
public class PreferenciaLembrete {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id", nullable = false, unique = true)
    private Usuario usuario;

    @Column(nullable = false)
    private boolean ligado = false;

    @Column(nullable = false)
    private int hora = 20;

    @Column(nullable = false)
    private int minuto = 0;

    @Column(name = "dias_semana_json", nullable = false, length = 60)
    private String diasSemanaCsv = "1,2,3,4,5,6,7";

    @Column(name = "data_ultima_atualizacao")
    private LocalDateTime dataUltimaAtualizacao;

    @PrePersist
    @PreUpdate
    protected void aoSalvar() {
        dataUltimaAtualizacao = LocalDateTime.now();
    }
}
