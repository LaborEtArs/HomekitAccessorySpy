//
// TLV8.h
//

#ifndef __TLV8_H__
#define __TLV8_H__


/*
 * stcTLV8Element
 *
 */
typedef struct _stcTLV8Element {
	unsigned char			m_ucTag;
	unsigned				m_uLength;
	const unsigned char*	m_pucValue;

	_stcTLV8Element*			m_pNextElement;

	_stcTLV8Element(void);
} stcTLV8Element;


/*
 * clsTLV8Reader
 *
 */
class clsTLV8Reader {

public:
	clsTLV8Reader(const unsigned char* p_pTVL8Stream, const unsigned p_uLength);
	virtual ~clsTLV8Reader();

	bool peekNext(unsigned char& p_rucType, unsigned& p_ruLength,
			const unsigned char*& p_rpucValue);
	bool next(unsigned char& p_rType, unsigned& p_rLength,
			const unsigned char*& p_rpucValue);

	void rewind(void);
	bool skip(void);

	bool isValid(void);

protected:
	const unsigned char*	m_pucTLVStream;
	const unsigned			m_uLength;

	bool					m_bValid;

	stcTLV8Element			m_head;
	stcTLV8Element*			m_pElementCursor;

	void _freeElementList(void);
	bool _fragmentAt(const unsigned char* p_pucElement,
			unsigned char& p_rucTag,
			unsigned char& p_rucLength);
	unsigned _valueLengthAt(const unsigned char* p_pucElement);

	/*void _print(const char* p_pcComment,
			const unsigned char* p_pucArray, int p_iLength);*/
};


/*
 * clsTLV8Writer
 *
 */
class clsTLV8Writer {

public:
	clsTLV8Writer(const unsigned p_uInitLength = 0);
	virtual ~clsTLV8Writer();

	bool addUC(const unsigned char p_ucTag,
			const unsigned char p_ucValue);
	bool add(const unsigned char p_ucTag,
			const unsigned p_uLength,
			const unsigned char* p_pucValue);

	unsigned length(void) const;
	const unsigned char* TLVStream(void) const;
	const unsigned char* TLVStream(unsigned& p_ruLength) const;

protected:
	unsigned char*	m_pucTLVStreamBuffer;
	unsigned		m_uBufferLength;
	unsigned char*	m_pucCursor;
};

#endif // __TLV8_H__





