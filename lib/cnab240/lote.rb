module Cnab240
  class Lote
    attr_accessor :header
    attr_accessor :segmentos
    attr_accessor :trailer
    attr_accessor :operacao
    attr_accessor :tipo
    attr_accessor :arquivo

    def initialize(options = {})
      @segmentos = []

      @operacao ||= options[:operacao]
      @tipo ||= options[:tipo]
      @versao ||= options[:versao]
      @fallback ||= options[:fallback]
      @versao ||= 'V86'

      fail "Operacao '#{operacao}' nao suportada na versao #{@versao}" if ESTRUTURA[@versao][operacao].nil?

      estrutura = ESTRUTURA[@versao][operacao]

      @header = estrutura[:header].new
      @trailer = estrutura[:trailer].new

      yield self if block_given?
    end

    def read_segmento(s, _line)
      versao = arquivo.versao unless arquivo.nil?
      versao ||= @versao
      segmentos << seg = eval("Cnab240::#{versao}::Segmento#{s.to_s.upcase}.read(_line)")
    end

    def <<(s)
      versao = arquivo.versao unless arquivo.nil?
      versao ||= @versao
      case s
      when Symbol, String
        segmentos << seg = eval("Cnab240::#{versao}::Segmento#{s.to_s.upcase}.new")
      else
        segmentos << seg = s
      end
      seg.lote = self
      seg
    end

    def linhas
      auto_fill if Cnab240.auto_fill_enabled
      seg_array = []
      seg_array << @header.linha
      segmentos.each do |s|
        seg_array << s.linha
      end
      seg_array << @trailer.linha
      seg_array
    end

    def string
      linhas.join("\n")
    end

    def auto_fill
      trailer.totais_qtde_registros = (segmentos.length + 2).to_s

      if trailer.respond_to?(:totais_valor)
        _total = 0
        segmentos.each { |seg| _total += seg[:credito_valor_pagamento].to_i }
        trailer.totais_valor = _total.to_s
      end

      # Quando o lote é de boletos
      if trailer.respond_to?(:qtde_cobranca_simples)
        _total = 0
        _qtde = 0
        segmentos.each do |seg|
          next unless seg.class.to_s =~ /SegmentoP/
          _qtde += 1
          _total += seg[:valor].to_i
        end
        trailer.qtde_cobranca_simples = _qtde.to_s
        trailer.total_cobranca_simples = _total.to_s
      end
    end
  end
end
