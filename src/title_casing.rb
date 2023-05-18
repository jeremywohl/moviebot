# rules:
#  when one of these words starts a title.
#  when one of these words ends a title.
#  when one of these words comes after a colon, as in a subtitle.
#  finally, when a quotation is part of a title, follow the capitalization used in the quote:

non_caps = [
 'a', 'aboard', 'about', 'above', 'absent', 'across', 'after', 'against',
 'along', 'alongside', 'amid', 'amidst', 'among', 'amongst', 'an', 'and',
 'around', 'as', 'as', 'aslant', 'astride', 'at', 'athwart', 'atop',
 'barring', 'before', 'behind', 'below', 'beneath', 'beside', 'besides',
 'between', 'beyond', 'but', 'by', 'despite', 'down', 'during', 'except',
 'failing', 'following', 'for', 'for', 'from', 'in', 'inside', 'into',
 'like', 'mid', 'minus', 'near', 'next', 'nor', 'notwithstanding', 'of',
 'off', 'on', 'onto', 'opposite', 'or', 'out', 'outside', 'over', 'past',
 'per', 'plus', 'regarding', 'round', 'save', 'since', 'so', 'than',
 'the', 'through', 'throughout', 'till', 'times', 'to', 'toward',
 'towards', 'under', 'underneath', 'unlike', 'until', 'up', 'upon', 'via',
 'vs.', 'when', 'with', 'within', 'without', 'worth', 'yet',
]

NON_CAPITAL_WORDS = Hash[non_caps.map { |x| [x, nil] }]

# Remove tracking bits, ours and makemkv's.
def clean_fn(s)
  # remove
  s = s.gsub(/^(\h{5}-)/, '')         # moviebot's random code
  s = s.gsub(/-FPL_MainFeature/, '')  # common extra titling

  # normalize
  s = s.gsub(/(_t\d{2})$/, '\2')      # makemkv's title ID (_txy -> xy)
  s = s.gsub(/_/, ' ')                # underscores to spaces
  s = s.gsub(/\s{2,}/, ' ')           # redundant whitespace
end

# Title case by standard English rules.
def title_case_fn(s)
  words = s.split(/[\W&&[^']]/)  # conserve apostrophes
  newwords = []

  words.each_with_index do |word, index|
    if index == 0 || index == words.length - 1
      newwords << word.capitalize
    elsif NON_CAPITAL_WORDS.has_key?(word.downcase)
      newwords << word.downcase
    else
      newwords << word.capitalize
    end
  end

  newwords.join(' ')
end
