package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.PreferenciaLembrete;
import lombok.Data;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Data
public class PreferenciaLembreteDTO {
    private boolean ligado;
    private int hora;
    private int minuto;
    private List<Integer> diasSemana;

    public static PreferenciaLembreteDTO fromEntity(PreferenciaLembrete p) {
        PreferenciaLembreteDTO dto = new PreferenciaLembreteDTO();
        dto.setLigado(p.isLigado());
        dto.setHora(p.getHora());
        dto.setMinuto(p.getMinuto());
        try {
            dto.setDiasSemana(Arrays.stream(p.getDiasSemanaCsv().split(","))
                    .filter(s -> !s.isBlank())
                    .map(Integer::parseInt)
                    .collect(Collectors.toList()));
        } catch (Exception e) {
            dto.setDiasSemana(List.of(1,2,3,4,5,6,7));
        }
        return dto;
    }

    public String diasCsv() {
        if (diasSemana == null || diasSemana.isEmpty()) return "1,2,3,4,5,6,7";
        return diasSemana.stream().map(String::valueOf).collect(Collectors.joining(","));
    }
}
