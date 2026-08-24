package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.PreferenciaLembreteDTO;
import com.giovanna.bibliotecabackend.model.PreferenciaLembrete;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.PreferenciaLembreteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PreferenciaLembreteService {

    private final PreferenciaLembreteRepository repository;
    private final UsuarioService usuarioService;

    @Transactional(readOnly = true)
    public PreferenciaLembreteDTO buscarOuCriarPadrao() {
        Usuario eu = usuarioService.obterUsuarioLogado();
        return repository.findByUsuario(eu)
                .map(PreferenciaLembreteDTO::fromEntity)
                .orElseGet(() -> {
                    PreferenciaLembreteDTO d = new PreferenciaLembreteDTO();
                    d.setLigado(false);
                    d.setHora(20);
                    d.setMinuto(0);
                    d.setDiasSemana(java.util.List.of(1,2,3,4,5,6,7));
                    return d;
                });
    }

    @Transactional
    public PreferenciaLembreteDTO salvar(PreferenciaLembreteDTO dto) {
        Usuario eu = usuarioService.obterUsuarioLogado();
        PreferenciaLembrete entidade = repository.findByUsuario(eu).orElseGet(() -> {
            PreferenciaLembrete nova = new PreferenciaLembrete();
            nova.setUsuario(eu);
            return nova;
        });

        entidade.setLigado(dto.isLigado());
        entidade.setHora(Math.max(0, Math.min(23, dto.getHora())));
        entidade.setMinuto(Math.max(0, Math.min(59, dto.getMinuto())));
        entidade.setDiasSemanaCsv(dto.diasCsv());

        PreferenciaLembrete salva = repository.save(entidade);
        return PreferenciaLembreteDTO.fromEntity(salva);
    }
}
