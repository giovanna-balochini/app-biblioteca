package com.giovanna.bibliotecabackend.config;

import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {

    public static final String EMAIL_USUARIO_PADRAO = "u...@exemplo.com";
    public static final String SENHA_USUARIO_PADRAO = "123456";

    public static final String EMAIL_DEV_GIOVANNA = "giovanabalo...@gmail.com";
    public static final String SENHA_DEV_GIOVANNA = "021623";

    private final UsuarioRepository usuarioRepository;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

        criarOuAtualizarConta(
            encoder,
            EMAIL_USUARIO_PADRAO,
            SENHA_USUARIO_PADRAO,
            "Usuário Padrão",
            "Primeiro usuário do sistema"
        );

        criarOuAtualizarConta(
            encoder,
            EMAIL_DEV_GIOVANNA,
            SENHA_DEV_GIOVANNA,
            "Giovanna",
            "Desenvolvedora — criadora do app biblioteca 📚"
        );

        try {
            migrarAvaliacoesLegadas();
        } catch (Exception ignored) {}
    }

    private void criarOuAtualizarConta(
            BCryptPasswordEncoder encoder,
            String email,
            String senhaTextoClaro,
            String nome,
            String bio
    ) {
        Optional<Usuario> existenteOpt = usuarioRepository.findByEmail(email);
        String hashNovo = encoder.encode(senhaTextoClaro);
        if (existenteOpt.isEmpty()) {
            Usuario u = new Usuario();
            u.setEmail(email);
            u.setSenha(hashNovo);
            u.setNome(nome);
            u.setBio(bio);
            usuarioRepository.save(u);
            return;
        }

        Usuario existente = existenteOpt.get();
        boolean precisaAtualizar = false;
        String senhaAtual = existente.getSenha();
        if (senhaAtual == null
                || senhaAtual.isBlank()
                || senhaAtual.equals(senhaTextoClaro)
                || !senhaAtual.startsWith("$2a$")) {
            precisaAtualizar = true;
        } else {
            boolean hashBate = false;
            try {
                hashBate = encoder.matches(senhaTextoClaro, senhaAtual);
            } catch (Exception ignored) {}
            if (!hashBate) precisaAtualizar = true;
        }
        if (nome != null && !nome.equalsIgnoreCase(existente.getNome())) {
            precisaAtualizar = true;
        }
        if (bio != null && existente.getBio() == null) {
            precisaAtualizar = true;
        }

        if (precisaAtualizar) {
            existente.setSenha(hashNovo);
            if (nome != null) existente.setNome(nome);
            if (bio != null && (existente.getBio() == null || existente.getBio().isBlank())) {
                existente.setBio(bio);
            }
            usuarioRepository.save(existente);
        }
    }

    private void migrarAvaliacoesLegadas() {
        Boolean temColunaAvaliacao = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM information_schema.columns " +
            "WHERE table_schema = DATABASE() AND table_name = 'livro' AND column_name = 'avaliacao'",
            Boolean.class
        );
        if (!Boolean.TRUE.equals(temColunaAvaliacao)) return;

        List<Map<String, Object>> linhas = jdbcTemplate.queryForList(
            "SELECT id, usuario_id, avaliacao, dataConclusao FROM livro WHERE avaliacao IS NOT NULL"
        );
        LocalDateTime agora = LocalDateTime.now();

        for (Map<String, Object> linha : linhas) {
            Long livroId = ((Number) linha.get("id")).longValue();
            Object usuarioIdObj = linha.get("usuario_id");
            Object avalObj = linha.get("avaliacao");
            Object dataObj = linha.get("dataConclusao");

            if (usuarioIdObj == null || avalObj == null) continue;
            Long usuarioId = ((Number) usuarioIdObj).longValue();
            int nota = ((Number) avalObj).intValue();
            if (nota < 1 || nota > 5) continue;

            Integer existe = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM avaliacao WHERE usuario_id = ? AND livro_id = ?",
                Integer.class, usuarioId, livroId
            );
            if (existe != null && existe > 0) continue;

            if (dataObj == null) {
                jdbcTemplate.update(
                    "INSERT INTO avaliacao (livro_id, usuario_id, nota, dataCriacao, dataAtualizacao) VALUES (?, ?, ?, ?, ?)",
                    livroId, usuarioId, nota, agora, agora
                );
            } else {
                jdbcTemplate.update(
                    "INSERT INTO avaliacao (livro_id, usuario_id, nota, dataConclusao, dataCriacao, dataAtualizacao) VALUES (?, ?, ?, ?, ?, ?)",
                    livroId, usuarioId, nota, dataObj, agora, agora
                );
            }
        }
    }
}
