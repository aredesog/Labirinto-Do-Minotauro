"""Leitor mínimo de .blend (Blender 5.x, cabeçalho grande) — só o necessário
para tirar malha, UV e textura de um modelo do Tripo3D."""
import struct
import sys


class Blend:
    def __init__(self, caminho):
        self.d = open(caminho, 'rb').read()
        if self.d[:4] == b'\x28\xb5\x2f\xfd':      # .blend comprimido (zstd)
            import zstandard
            import io
            saida = io.BytesIO()
            zstandard.ZstdDecompressor().copy_stream(io.BytesIO(self.d), saida)
            self.d = saida.getvalue()
        d = self.d
        assert d[:7] == b'BLENDER'
        if d[7:9] == b'17':          # formato novo (5.x): 17 bytes
            self.ptr = 8
            self.pos = 17
            self.novo = True
        else:
            self.ptr = 8 if d[7:8] == b'-' else 4
            self.pos = 12
            self.novo = False
        self.blocos = []
        self.por_end = {}
        p = self.pos
        while p < len(d):
            if self.novo:
                code, sdna, old, ln, nr = struct.unpack_from('<4sIQqq', d, p)
                p += 32
            else:
                code, ln, old, sdna, nr = struct.unpack_from('<4siQii', d, p)
                p += 24
            b = dict(code=code.rstrip(b'\0'), sdna=sdna, old=old, len=ln, nr=nr, off=p)
            self.blocos.append(b)
            if old:
                self.por_end[old] = b
            p += ln
            if b['code'] == b'ENDB':
                break
        self._ler_dna()

    def _ler_dna(self):
        b = [x for x in self.blocos if x['code'] == b'DNA1'][0]
        d = self.d
        p = b['off']
        assert d[p:p + 4] == b'SDNA'
        p += 4

        base = b['off']

        def alinhar(p):
            return base + (((p - base) + 3) & ~3)

        def strings(p, n):
            out = []
            for _ in range(n):
                e = d.index(b'\0', p)
                out.append(d[p:e].decode('latin1'))
                p = e + 1
            return out, p
        assert d[p:p + 4] == b'NAME'
        n, = struct.unpack_from('<i', d, p + 4)
        self.nomes, p = strings(p + 8, n)
        p = alinhar(p)
        assert d[p:p + 4] == b'TYPE'
        n, = struct.unpack_from('<i', d, p + 4)
        self.tipos, p = strings(p + 8, n)
        p = alinhar(p)
        assert d[p:p + 4] == b'TLEN'
        self.tlen = struct.unpack_from('<%dH' % n, d, p + 4)
        p = alinhar(p + 4 + 2 * n)
        assert d[p:p + 4] == b'STRC'
        ns, = struct.unpack_from('<i', d, p + 4)
        p += 8
        self.structs = []
        self.struct_de_tipo = {}
        for i in range(ns):
            t, nc = struct.unpack_from('<hh', d, p)
            p += 4
            campos = []
            for _ in range(nc):
                ft, fn = struct.unpack_from('<hh', d, p)
                p += 4
                campos.append((self.tipos[ft], self.nomes[fn]))
            self.structs.append((self.tipos[t], campos))
            self.struct_de_tipo[self.tipos[t]] = i

    def tamanho_campo(self, tipo, nome):
        import re
        mult = 1
        for m in re.findall(r'\[(\d+)\]', nome):
            mult *= int(m)
        if nome.startswith('*') or nome.startswith('(*'):
            return self.ptr * mult
        return self.tlen[self.tipos.index(tipo)] * mult

    def layout(self, nome_struct):
        """{campo: (offset, tipo, nome_cru)}"""
        i = self.struct_de_tipo[nome_struct]
        off = 0
        out = {}
        for tipo, nome in self.structs[i][1]:
            limpo = nome.lstrip('*').split('[')[0].replace('(', '').replace(')', '')
            out[limpo] = (off, tipo, nome)
            off += self.tamanho_campo(tipo, nome)
        return out

    def struct_nome(self, bloco):
        return self.structs[bloco['sdna']][0]

    def ler(self, bloco_off, nome_struct, campo, base=0):
        lay = self.layout(nome_struct)
        off, tipo, nome = lay[campo]
        p = bloco_off + base + off
        if nome.startswith('*'):
            return struct.unpack_from('<Q', self.d, p)[0]
        fmt = {'int': 'i', 'float': 'f', 'short': 'h', 'char': 'b', 'uchar': 'B', 'int64_t': 'q',
               'uint64_t': 'Q', 'int32_t': 'i', 'uint32_t': 'I', 'int8_t': 'b', 'int16_t': 'h', 'uint8_t': 'B'}
        if tipo == 'char' and '[' in nome:
            n = self.tamanho_campo(tipo, nome)
            s = self.d[p:p + n]
            return s.split(b'\0')[0].decode('utf8', 'replace')
        if tipo in fmt:
            return struct.unpack_from('<' + fmt[tipo], self.d, p)[0]
        return p  # sub-struct: devolve o offset absoluto

    def bloco(self, endereco):
        return self.por_end.get(endereco)

    def dados(self, endereco):
        b = self.bloco(endereco)
        return None if b is None else self.d[b['off']:b['off'] + b['len']]


if __name__ == '__main__':
    bf = Blend(sys.argv[1])
    from collections import Counter
    print(Counter(bf.struct_nome(b) if b['sdna'] < len(bf.structs) else '?' for b in bf.blocos if b['code'] != b'DATA').most_common(30))
    for nome in sys.argv[2:]:
        print(nome, list(bf.layout(nome).items()))
