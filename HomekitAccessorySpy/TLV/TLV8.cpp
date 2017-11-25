//
// TLV8.cpp
//
#include <string.h>

#include "TLV8.h"

#ifndef MIN
#define MIN(A, B)	((A<B)?A:B)
#endif

#ifndef MAX
#define MAX(A, B)	((A>B)?A:B)
#endif

/*
 * _stcTLV8Element
 *
 */

/*
 * _stcTLV8Element-Constructor
 *
 */
_stcTLV8Element::_stcTLV8Element(void) {

	memset(this, 0, sizeof(*this));
}

/*
 * clsTLV8Reader
 *
 */

/*
 * clsTLV8Reader-Constructor
 *
 */
clsTLV8Reader::clsTLV8Reader(const unsigned char* p_pucTLVStream,
		const unsigned p_uLength)
:	m_pucTLVStream(p_pucTLVStream),
	m_uLength(p_uLength),
	m_bValid(false),
	m_pElementCursor(m_head.m_pNextElement) {

	//Serial.printf("Got(2): %x,%x,%x\n", *p_pucTLVStream, *(p_pucTLVStream + 1), *(p_pucTLVStream + 2));

	if ((m_pucTLVStream) &&
		(p_uLength)) {

		m_bValid = true;
		const unsigned char*	pucFragmentCursor = m_pucTLVStream;
		stcTLV8Element*			pCurrentElement = &m_head;

		while ((pucFragmentCursor < (m_pucTLVStream + p_uLength)) &&
			   (m_bValid)) {

			//Serial.printf("Reading %x with len %x [%x]\n", *pucFragmentCursor, *(pucFragmentCursor + 1), *(pucFragmentCursor + 2));

			pCurrentElement->m_pNextElement = new stcTLV8Element;
			pCurrentElement = pCurrentElement->m_pNextElement;

			pCurrentElement->m_uLength = _valueLengthAt(pucFragmentCursor);

			if (255 >= pCurrentElement->m_uLength) {
				//unfragmented value

				unsigned char ucLength;
				if (_fragmentAt(pucFragmentCursor, pCurrentElement->m_ucTag, ucLength)) {

					pCurrentElement->m_pucValue = (pucFragmentCursor + 2);

					pucFragmentCursor += (2 + ucLength);
				}
				else {
					// error
					m_bValid = false;
					_freeElementList();
				}
			}
			else {
				// fragmented value > 255 bytes
				pCurrentElement->m_pucValue = new unsigned char[pCurrentElement->m_uLength];
				unsigned char*	pCursorInValueBuffer = (unsigned char*) pCurrentElement->m_pucValue;

				unsigned		curLen = 0;
				//pElementCursor = pCursor;
				while (curLen < pCurrentElement->m_uLength) {
					unsigned char	ucLength;
					if (_fragmentAt(pucFragmentCursor, pCurrentElement->m_ucTag, ucLength)) {

						memcpy(pCursorInValueBuffer, (pucFragmentCursor + 2), ucLength);
						pCursorInValueBuffer += ucLength;
						curLen += ucLength;

						pucFragmentCursor += (2 + ucLength);
					}
					else {
						// error
						m_bValid = false;
						_freeElementList();
						break;
					}
				}
			}
			/*if (m_bValid) {
				char s[30];
				sprintf(s, "[TLV] Tag:0x%02x (len:%u), ", pCurrentElement->m_ucType, pCurrentElement->m_uLength);
				print(s, pCurrentElement->m_pucValue, pCurrentElement->m_uLength);
			}*/
		}	// while

		if (m_bValid) {
			m_pElementCursor = m_head.m_pNextElement;
		}
	}
}

/*
 * clsTLV8Reader-Destructor
 *
 */
clsTLV8Reader::~clsTLV8Reader(void) {

	_freeElementList();
}

/*
 clsTLV8Reader::peekNext
 
 */
bool clsTLV8Reader::peekNext(unsigned char& p_rucTag,
		unsigned& p_ruLength,
		const unsigned char*& p_rpucValue) {

	if ((m_bValid) && (m_pElementCursor)) {

		p_rucTag = m_pElementCursor->m_ucTag;		// may be 0
		p_ruLength = m_pElementCursor->m_uLength;	// may be 0
		p_rpucValue = m_pElementCursor->m_pucValue;	// may be NULL

		return true;
	}
	else {
		p_rucTag = 0;
		p_ruLength = 0;
		p_rpucValue = NULL;

		return false;
	}
}

/*
 clsTLV8Reader::next
 
 */
bool clsTLV8Reader::next(unsigned char& p_rucTag,
		unsigned& p_ruLength,
		const unsigned char*& p_rpucValue) {

	if (peekNext(p_rucTag, p_ruLength, p_rpucValue)) {
		m_pElementCursor = m_pElementCursor->m_pNextElement;

		return true;
	}
	else {
		return false;
	}
}

/*
 clsTLV8Reader::rewind
 
 */
void clsTLV8Reader::rewind(void) {

	m_pElementCursor = m_head.m_pNextElement;
}

/*
 clsTLV8Reader::skip
 
 */
bool clsTLV8Reader::skip(void) {

	if (m_pElementCursor) {
		m_pElementCursor = m_pElementCursor->m_pNextElement;
		return true;
	}
	else {
		return false;
	}
}

/*
 clsTLV8Reader::isValid

 */
bool clsTLV8Reader::isValid(void) {

	return m_bValid;
}

/*
 *
 * PROTECTED
 *
 */

/*
 clsTLV8Reader::_freeElementList
 
 */
void clsTLV8Reader::_freeElementList(void) {

	stcTLV8Element* pNextElement = m_head.m_pNextElement;
	while (pNextElement) {
		stcTLV8Element*	pElementToDelete = pNextElement;
		pNextElement = pNextElement->m_pNextElement;

		if (255 < pElementToDelete->m_uLength) {
			// element owns value buffer
			delete[] pElementToDelete->m_pucValue;
		}
		delete pElementToDelete;
	}
	m_head.m_pNextElement = NULL;
}

/*
 clsTLV8Reader::_fragmentAt
 
 */
bool clsTLV8Reader::_fragmentAt(const unsigned char* p_pucElement,
		unsigned char& p_rucTag,
		unsigned char& p_rucLength) {

	if (((p_pucElement + 2) <= (m_pucTLVStream + m_uLength)) &&
		((p_pucElement + 2 + (*(p_pucElement + 1)))	<= (m_pucTLVStream + m_uLength))) {

		p_rucTag = *(p_pucElement);
		p_rucLength = *(p_pucElement + 1);
		return true;
	}
	else {
		p_rucTag = 0;
		p_rucLength = 0;
		return false;
	}
}

/*
 clsTLV8Reader::_valueLengthAt
 
 */
unsigned clsTLV8Reader::_valueLengthAt(const unsigned char* p_pucElement) {

	unsigned uValueLength = 0;

	unsigned char	ucFirstFragmentType;
	unsigned char	ucFragmentLength;

	if (_fragmentAt(p_pucElement, ucFirstFragmentType, ucFragmentLength)) {
		uValueLength = ucFragmentLength;

		const unsigned char*	pNextFragment = (p_pucElement + 2 + ucFragmentLength);
		unsigned char			ucNextFragmentType;

		while ((255 == ucFragmentLength) &&	// Maybe fragmented
			   (_fragmentAt(pNextFragment, ucNextFragmentType, ucFragmentLength)) &&	// next element available
			   (ucFirstFragmentType == ucNextFragmentType)) {	// same type

			uValueLength += ucFragmentLength;

			pNextFragment += (2 + ucFragmentLength);
		}
	}
	return uValueLength;
}

/*
 * print(unsigned char*)
 *
 * /
void clsTLV8Reader::_print(const char* p_pcComment,
		const unsigned char* p_pucArray, int p_iLength) {

	Serial.printf("%s\n", p_pcComment);
	for (int j = 1; ((j <= p_iLength) && (j <= 16)); ++j) {
		//Serial.write (array[j]);//Serial.write() transmits the ASCII numbers as human readable characters to serial monitor
		char s[3];
		sprintf(s, "0x%02x, ", p_pucArray[j - 1]);
		Serial.printf("%s", s);
		if (!(j % 16)) {
			Serial.printf("\n");
		}
	}
	Serial.printf("\n");
}*/


/*
 * clsTLV8Writer
 *
 */

/*
 * clsTLV8Writer-Construktor
 *
 */
clsTLV8Writer::clsTLV8Writer(const unsigned p_uInitLength /*= 0*/)
:	m_pucTLVStreamBuffer(NULL),
	m_uBufferLength(0),
	m_pucCursor(0) {

	if (p_uInitLength) {
		m_pucCursor = m_pucTLVStreamBuffer = new unsigned char[p_uInitLength];
		m_uBufferLength = p_uInitLength;
	}
}

/*
 * clsTLV8Writer-Destruktor
 *
 */
clsTLV8Writer::~clsTLV8Writer(void) {

	delete[] m_pucTLVStreamBuffer;
}

/*
 * clsTLV8Writer::addUC
 *
 */
bool clsTLV8Writer::addUC(const unsigned char p_ucTag,
		const unsigned char p_ucValue) {

	return add(p_ucTag, 1, &p_ucValue);
}

/*
 * clsTLV8Writer::add
 *
 */
bool clsTLV8Writer::add(const unsigned char p_ucTag,
		const unsigned p_uLength,
		const unsigned char* p_pucValue) {

	unsigned uNeededFragments = ((p_uLength / 255) + ((p_uLength % 255) ? 1 : 0));
	int		leftSpace = (int)((m_pucTLVStreamBuffer + m_uBufferLength - m_pucCursor) - ((2 * uNeededFragments) + p_uLength));
	if (0 > leftSpace) {
		// more space needed
		unsigned		uNewBufferLength = (m_uBufferLength + (-leftSpace));
		unsigned char*	pucNewBuffer = new unsigned char[uNewBufferLength];

		memcpy(pucNewBuffer, m_pucTLVStreamBuffer, m_uBufferLength);
		m_pucCursor = (pucNewBuffer + (m_pucCursor - m_pucTLVStreamBuffer));

		delete[] m_pucTLVStreamBuffer;
		m_pucTLVStreamBuffer = pucNewBuffer;
		m_uBufferLength = uNewBufferLength;
	}

	unsigned				uRemainder = p_uLength;
	const unsigned char*	pCursorInValue = p_pucValue;
	while (uRemainder) {
		unsigned uFragmentLength = MIN(uRemainder, 255);

		*(m_pucCursor++) = p_ucTag;
		*(m_pucCursor++) = uFragmentLength;
		memcpy(m_pucCursor, pCursorInValue, uFragmentLength);
		m_pucCursor += uFragmentLength;

		pCursorInValue += uFragmentLength;
		uRemainder -= uFragmentLength;
	}
	return true;
}

/*
 clsTLV8Writer::length
 
 */
unsigned clsTLV8Writer::length(void) const {

	return (unsigned)(m_pucCursor - m_pucTLVStreamBuffer);
}

/*
 clsTLV8Writer::TLVStream
 
 */
const unsigned char* clsTLV8Writer::TLVStream(void) const {

	return m_pucTLVStreamBuffer;
}

/*
 clsTLV8Writer::TLVStream

 */
const unsigned char* clsTLV8Writer::TLVStream(unsigned& p_ruLength) const {

	p_ruLength = length();
	return m_pucTLVStreamBuffer;
}






