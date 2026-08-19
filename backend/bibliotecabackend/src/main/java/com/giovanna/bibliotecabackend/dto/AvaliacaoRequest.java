package com.giovanna.bibliotecabackend.dto;

import lombok.Data;
import java.time.LocalDate;

@Data
public class AvaliacaoRequest {
    private Integer nota;
    private String comentario;
    private String dataConclusao;
}
