package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.PublicUserProfileDTO;
import com.giovanna.bibliotecabackend.model.Seguidor;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.SeguidorRepository;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collections;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class SeguidorService {

    private final SeguidorRepository seguidorRepository;
    private final UsuarioRepository usuarioRepository;

    private Optional<Usuario> obterUsuarioLogadoSeAutenticado() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof Usuario u) {
                return Optional.of(u);
            }
        } catch (Exception ignored) {}
        return Optional.empty();
    }

    private Usuario obterUsuarioLogadoOuPadrao() {
        return obterUsuarioLogadoSeAutenticado()
                .orElseGet(() -> usuarioRepository.findByEmail("u...@exemplo.com")
                        .orElse(null));
    }

    public long totalSeguidores(Usuario usuario) {
        return seguidorRepository.countBySeguido(usuario);
    }

    public long totalSeguindo(Usuario usuario) {
        return seguidorRepository.countBySeguidor(usuario);
    }

    public boolean estouSeguindo(Usuario alvo) {
        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        if (euOpt.isEmpty() || alvo == null) return false;
        Usuario eu = euOpt.get();
        if (eu.getId() != null && eu.getId().equals(alvo.getId())) return false;
        return seguidorRepository.existsBySeguidorAndSeguido(eu, alvo);
    }

    public boolean segueVoce(Usuario alvo) {
        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        if (euOpt.isEmpty() || alvo == null) return false;
        Usuario eu = euOpt.get();
        if (eu.getId() != null && eu.getId().equals(alvo.getId())) return false;
        return seguidorRepository.existsBySeguidorAndSeguido(alvo, eu);
    }

    public List<Long> idsDosQueEuSigo() {
        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        if (euOpt.isEmpty()) return Collections.emptyList();
        return seguidorRepository.findIdsSeguidosPor(euOpt.get());
    }

    public Page<PublicUserProfileDTO> listarSeguidoresPaginado(Usuario alvo, int pagina, int tamanho) {
        Pageable pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));
        Page<Usuario> paginaUsuarios = seguidorRepository.findSeguidoresDe(alvo, pageable);
        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        return paginaUsuarios.map(u -> PublicUserProfileDTO.fromUsuarioResumido(
                u,
                seguidorRepository.existsBySeguidorAndSeguido(euOpt.orElse(null), u),
                seguidorRepository.existsBySeguidorAndSeguido(u, euOpt.orElse(null)),
                euOpt.isPresent() && euOpt.get().getId() != null && euOpt.get().getId().equals(u.getId()),
                seguidorRepository.countBySeguido(u),
                seguidorRepository.countBySeguidor(u)
        ));
    }

    public Page<PublicUserProfileDTO> listarSeguindoPaginado(Usuario alvo, int pagina, int tamanho) {
        Pageable pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));
        Page<Usuario> paginaUsuarios = seguidorRepository.findSeguindoDe(alvo, pageable);
        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        return paginaUsuarios.map(u -> PublicUserProfileDTO.fromUsuarioResumido(
                u,
                seguidorRepository.existsBySeguidorAndSeguido(euOpt.orElse(null), u),
                seguidorRepository.existsBySeguidorAndSeguido(u, euOpt.orElse(null)),
                euOpt.isPresent() && euOpt.get().getId() != null && euOpt.get().getId().equals(u.getId()),
                seguidorRepository.countBySeguido(u),
                seguidorRepository.countBySeguidor(u)
        ));
    }

    @Transactional
    public Seguidor seguir(Long idAlvo) {
        Usuario eu = obterUsuarioLogadoOuPadrao();
        if (eu == null) throw new IllegalStateException("Usuário não autenticado");
        Usuario alvo = usuarioRepository.findById(idAlvo)
                .orElseThrow(() -> new IllegalArgumentException("Usuário não encontrado"));
        if (eu.getId() != null && eu.getId().equals(alvo.getId())) {
            throw new IllegalArgumentException("Você não pode seguir a si mesmo");
        }
        if (seguidorRepository.existsBySeguidorAndSeguido(eu, alvo)) {
            return seguidorRepository.findBySeguidorAndSeguido(eu, alvo).orElseThrow();
        }
        Seguidor s = new Seguidor();
        s.setSeguidor(eu);
        s.setSeguido(alvo);
        return seguidorRepository.save(s);
    }

    @Transactional
    public void desseguir(Long idAlvo) {
        Usuario eu = obterUsuarioLogadoOuPadrao();
        if (eu == null) throw new IllegalStateException("Usuário não autenticado");
        Usuario alvo = usuarioRepository.findById(idAlvo)
                .orElseThrow(() -> new IllegalArgumentException("Usuário não encontrado"));
        seguidorRepository.deleteBySeguidorAndSeguido(eu, alvo);
    }
}
