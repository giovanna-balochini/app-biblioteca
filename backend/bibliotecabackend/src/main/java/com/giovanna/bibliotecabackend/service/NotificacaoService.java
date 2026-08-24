package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.NotificacaoDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Notificacao;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.NotificacaoRepository;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class NotificacaoService {

    private final NotificacaoRepository notificacaoRepository;
    private final UsuarioRepository usuarioRepository;

    public Page<NotificacaoDTO> listarMinhasPaginado(int pagina, int tamanho, Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        PageRequest pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));
        return notificacaoRepository.findByUsuarioOrderByDataCriacaoDesc(usuario, pageable)
                .map(NotificacaoDTO::fromEntity);
    }

    public long contarNaoLidas(Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        return notificacaoRepository.countByUsuarioAndLidaFalse(usuario);
    }

    @Transactional
    public long marcarTodasComoLidas(Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        return notificacaoRepository.marcarTodasComoLidas(usuario);
    }

    @Transactional
    public boolean marcarUmaComoLida(Long id, Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        Optional<Notificacao> opt = notificacaoRepository.findById(id);
        if (opt.isEmpty()) return false;
        Notificacao n = opt.get();
        if (!n.getUsuario().getId().equals(usuario.getId())) return false;
        if (!n.isLida()) {
            n.setLida(true);
            notificacaoRepository.save(n);
        }
        return true;
    }

    @Transactional
    public boolean excluir(Long id, Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        if (!notificacaoRepository.existsByIdAndUsuario(id, usuario)) return false;
        notificacaoRepository.deleteById(id);
        return true;
    }

    @Transactional
    public long limparTodas(Long usuarioAutenticadoId) {
        Usuario usuario = usuarioRepository.getReferenceById(usuarioAutenticadoId);
        return notificacaoRepository.deleteByUsuario(usuario);
    }

    public void criarNotificacaoSeguir(Usuario seguidor, Usuario seguido) {
        if (seguidor.getId().equals(seguido.getId())) return;
        Notificacao n = new Notificacao();
        n.setUsuario(seguido);
        n.setTipo(Notificacao.TipoNotificacao.SEGUIR);
        n.setConteudo("começou a seguir você");
        n.setAutor(seguidor);
        n.setDadoId(seguidor.getId());
        n.setDadoNome(seguidor.getNome());
        n.setFotoUrl(seguidor.getFotoPerfil());
        notificacaoRepository.save(n);
    }

    public void criarNotificacaoAvaliacao(Avaliacao avaliacao) {
        if (avaliacao.getLivro() == null || avaliacao.getLivro().getDono() == null) return;
        Usuario donoDoLivro = avaliacao.getLivro().getDono();
        if (donoDoLivro.getId().equals(avaliacao.getAutor().getId())) return;

        Notificacao n = new Notificacao();
        n.setUsuario(donoDoLivro);
        n.setTipo(Notificacao.TipoNotificacao.AVALIACAO);
        n.setConteudo("avaliou \"" + avaliacao.getLivro().getTitulo() + "\" com " + avaliacao.getNota() + " estrelas");
        n.setAutor(avaliacao.getAutor());
        n.setDadoId(avaliacao.getLivro().getId());
        n.setDadoNome(avaliacao.getLivro().getTitulo());
        n.setFotoUrl(avaliacao.getLivro().getImagem());
        notificacaoRepository.save(n);
    }

    public void criarNotificacaoCurtida(Usuario autorDaAvaliacao, Usuario quemCurtiu, Avaliacao avaliacao) {
        if (autorDaAvaliacao == null || quemCurtiu == null || avaliacao == null) return;
        if (autorDaAvaliacao.getId().equals(quemCurtiu.getId())) return;
        Notificacao n = new Notificacao();
        n.setUsuario(autorDaAvaliacao);
        n.setTipo(Notificacao.TipoNotificacao.CURTIDA);
        String titulo = avaliacao.getLivro() != null ? avaliacao.getLivro().getTitulo() : "sua avaliação";
        n.setConteudo("curtiu sua avaliação de \"" + titulo + "\"");
        n.setAutor(quemCurtiu);
        n.setDadoId(avaliacao.getId());
        n.setDadoNome(titulo);
        n.setFotoUrl(quemCurtiu.getFotoPerfil());
        notificacaoRepository.save(n);
    }
}
