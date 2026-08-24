package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.config.DataInitializer;
import com.giovanna.bibliotecabackend.dto.PublicUserProfileDTO;
import com.giovanna.bibliotecabackend.dto.UsuarioBuscaDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import com.giovanna.bibliotecabackend.repository.SeguidorRepository;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class UsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final LivroRepository livroRepository;
    private final AvaliacaoRepository avaliacaoRepository;
    private final SeguidorRepository seguidorRepository;

    public java.util.List<Usuario> listarTodos() {
        return usuarioRepository.findAll();
    }

    public Optional<Usuario> buscarPorId(Long id) {
        return usuarioRepository.findById(id);
    }

    public Optional<Usuario> buscarPorEmail(String email) {
        return usuarioRepository.findByEmail(email);
    }

    public Usuario salvar(Usuario usuario) {
        if (usuario.getSenha() != null && !usuario.getSenha().startsWith("$2a$")) {
            usuario.setSenha(new BCryptPasswordEncoder().encode(usuario.getSenha()));
        }
        return usuarioRepository.save(usuario);
    }

    public void deletar(Long id) {
        usuarioRepository.deleteById(id);
    }

    public boolean existePorEmail(String email) {
        return usuarioRepository.existsByEmail(email);
    }

    public Usuario obterUsuarioPadrao() {
        return buscarPorEmail(DataInitializer.EMAIL_USUARIO_PADRAO).orElseThrow(() ->
                new IllegalStateException("Usuário padrão não inicializado"));
    }

    public Usuario obterUsuarioLogado() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (principal instanceof Usuario usuario) {
            return usuario;
        }
        return obterUsuarioPadrao();
    }

    public Optional<Usuario> obterUsuarioLogadoSeAutenticado() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && auth.getPrincipal() instanceof Usuario u) {
                return Optional.of(u);
            }
        } catch (Exception ignored) {}
        return Optional.empty();
    }

    private Long idUsuarioLogadoOuNulo() {
        return obterUsuarioLogadoSeAutenticado().map(Usuario::getId).orElse(null);
    }

    public Optional<PublicUserProfileDTO> obterPerfilPublico(Long idUsuario) {
        return usuarioRepository.findById(idUsuario).map(u -> {
            long totalLivros = livroRepository.countByDono(u);
            long totalAvaliacoes = avaliacaoRepository.countByAutor(u);
            Double media = avaliacaoRepository.calcularMediaPorAutor(u);

            Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
            Usuario eu = euOpt.orElse(null);
            boolean mesmoUsuario = eu != null
                    && eu.getId() != null
                    && u.getId() != null
                    && eu.getId().equals(u.getId());

            long totalSeguidores = seguidorRepository.countBySeguido(u);
            long totalSeguindo = seguidorRepository.countBySeguidor(u);
            boolean estouSeguindo = !mesmoUsuario && eu != null
                    && seguidorRepository.existsBySeguidorAndSeguido(eu, u);
            boolean segueVoce = !mesmoUsuario && eu != null
                    && seguidorRepository.existsBySeguidorAndSeguido(u, eu);

            return PublicUserProfileDTO.fromEntity(
                    u, totalLivros, totalAvaliacoes, media,
                    totalSeguidores, totalSeguindo, estouSeguindo, segueVoce,
                    idUsuarioLogadoOuNulo()
            );
        });
    }

    public Page<Avaliacao> listarAvaliacoesPublicasDoUsuario(Long idUsuario, int pagina, int tamanho) {
        Usuario u = usuarioRepository.findById(idUsuario).orElseThrow(() ->
                new IllegalArgumentException("Usuário não encontrado"));
        if (pagina < 0) pagina = 0;
        if (tamanho < 1 || tamanho > 100) tamanho = 20;
        PageRequest pageRequest = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));
        return avaliacaoRepository.findByAutorPaginado(u, pageRequest);
    }

    public Page<UsuarioBuscaDTO> buscarUsuarios(String q, int pagina, int tamanho) {
        if (q == null || q.trim().isEmpty()) {
            q = "";
        }
        if (pagina < 0) pagina = 0;
        if (tamanho < 1 || tamanho > 50) tamanho = 20;
        Pageable pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.ASC, "nome"));
        Page<Usuario> paginaUsuarios = usuarioRepository.buscarPorNomeOuEmail(q.trim(), pageable);

        Optional<Usuario> euOpt = obterUsuarioLogadoSeAutenticado();
        Usuario eu = euOpt.orElse(null);

        return paginaUsuarios.map(u -> {
            boolean mesmoUsuario = eu != null && eu.getId() != null && u.getId() != null
                    && eu.getId().equals(u.getId());
            boolean estouSeguindo = !mesmoUsuario && eu != null
                    && seguidorRepository.existsBySeguidorAndSeguido(eu, u);
            boolean segueVoce = !mesmoUsuario && eu != null
                    && seguidorRepository.existsBySeguidorAndSeguido(u, eu);
            long totalLivros = livroRepository.countByDono(u);
            long totalAvaliacoes = avaliacaoRepository.countByAutor(u);
            Double media = avaliacaoRepository.calcularMediaPorAutor(u);
            long totalSeguidores = seguidorRepository.countBySeguido(u);
            return UsuarioBuscaDTO.fromEntity(
                    u, totalLivros, totalAvaliacoes, media,
                    totalSeguidores, estouSeguindo, segueVoce, mesmoUsuario
            );
        });
    }
}
