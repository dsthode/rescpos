module Rescpos
	module ReportUtil
		FONT_NORMAL = "\x00"
		FONT_BIG = "\x11"
		WEIGHT_BOLD = "\x08"
		WEIGHT_NORMAL = "\x00"
		ALIGN_C = "\x01"
		ALIGN_L = "\x00"
		ALIGN_R = "\x02"
		BARCODE_UPCA = 65
		BARCODE_UPCE = 66
		BARCODE_EAN13 = 67
		BARCODE_EAN8 = 68
		BARCODE_CODE39 = 69
		BARCODE_ITF = 70
		BARCODE_CODABAR = 71
		BARCODE_CODE93 = 72
		BARCODE_CODE128 = 73

		def single_splitline
			text("-" * 42, :font_size => FONT_NORMAL)
		end

		def double_splitline
			text("=" * 42, :font_size => FONT_NORMAL)
		end

		def underline(number)
			text("_" * number, :font_size => FONT_NORMAL)
		end

		def chinese(chinese)
			text = string.encode('GBK', 'UTF-8', :invalid => :replace, :undef => :replace, :replace => '')
			#text = Iconv.iconv("GBK//IGNORE","UTF-8//IGNORE",chinese)
			text[0]
		end

		def text(txt, options = {}) 
			font_size = options[:font_size] || FONT_NORMAL
			formatted_text = ''
			formatted_text << weight(options[:weight]) if options[:weight]
			formatted_text << fontsize(font_size)
			formatted_text << grayscale(options[:gray]) if options[:gray]
			formatted_text << align(options[:align_type]) if options[:align_type]
			formatted_text << txt if txt
		end
		
		def weight(bold)
			"\x1b\x21" << bold.to_s
		end

		def fontsize(size)
			"\x1d\x21" << size.to_s
		end

		def grayscale(value)
			"\x1b\x6d" << ascii(value)
		end

		def key_value(label, value)
			"#{label}: #{value}"
		end

		def align(type)
			"\x1b\x61" << type.to_s
		end
		
		def table(data)
			table = Rescpos::Table.new(data)
			yield table
			# FIXME move the following logic into Rescpos::Table
			command = "\x1b\x44"
			table.positions.each do |position|
				command << position.chr
			end
			command << "\x00"
			if table.headers
				table.headers.each do |header|
					command << header << "\x09" 
				end
				command << "\n"
			end
			table.data.each do |item|
				if item.is_a? Array
					command = command + item.join("\x09") + (table.data.last == item ? "" : "\n")
				else
					table.keys.each do |key|
						if item.is_a? Hash
							command << "#{item[key]}\x09"
						else
							command << "#{item.send(key)}\x09"
						end
					end
					if table.data.last == item
						return command
					end
					command << "\n"
				end
			end
			command
		end

		def horizontal_tab
			"\x09"
		end
		
		def ascii(value)
			value.to_s.unpack('U')[0].to_s(16)
		end

		def full_cut
			"\n\x1d\x56#{65.chr}\x0c"
		end

		def partial_cut
			"\n\x1d\x56#{66.chr}\x0c"
		end

		def barcode(code, options)
			"\n\x1d\x77\x02\x1d\x48\x02\x1d\x6b#{options[:type].chr}#{code.size.chr}#{code}"
		end

		def image(image_file)
			base_store_command = "\x1d\x38\x4c" +
				"\x0b\x00\x00\x00" +
				"\x30\x70\x30" +
				"\x01\x01\x31" +
				"\x00\x00\x00\x00"
			print_command = "\x1d\x28\x4c\x02\x00\x30\x32"
			commands = ''
			image = ::Magick::Image::read(image_file).first
			if image
				if image.depth > 1
					image = image.quantize(2)
				end
				image_w = image.columns
				image_h = image.rows
				image_bytes = image.export_pixels(0, 0, image.columns, image.rows, 'I')
				chunk_size = 128
				bitmap_w = ((image_w + 7) >> 3) << 3
				bitmap_size = image_h * (bitmap_w >> 3)
				bitmap = Array.new(bitmap_size)
				for i in 0..(image_bytes.size-1)
					bitmap[i] = 0
					if image_bytes[i] >= 1
						x = i % image_w
						y = i / image_w
						bitmap[(y * bitmap_w + x) >> 3] |= 0x80 >> (x & 0x07)
					end
				end
				k = chunk_size
				0.step(image_h, k) do |l|
					if k > image_h + l
						k = image_h + l
					end
					p = 10 + k * (bitmap_w >> 3)
					base_store_command[3] = (p	& 0xff).chr
					base_store_command[4] = (p >> 8 & 0xff).chr
					base_store_command[13] = (bitmap_w & 0xff).chr
					base_store_command[14] = (bitmap_w >> 8 & 0xff).chr
					base_store_command[15] = (k & 0xff).chr
					base_store_command[16] = (k >> 8 && 0xff).chr
					commands << base_store_command
					(l * (bitmap_w >> 3)).upto(k * (bitmap_w >> 3)) do |pos|
						commands << bitmap[pos].chr
					end
					commands << print_command
					break
				end
			end
			commands
		end

		def image2(image_file)
		end
	end
end
