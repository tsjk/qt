# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="3"
inherit qt4-build

DESCRIPTION="The assistant help module for the Qt toolkit."
SLOT="4"
KEYWORDS="~amd64 ~x86"
IUSE="doc +glib trace"

DEPEND="
	~x11-libs/qt-gui-${PV}[=,glib=,trace?]
	~x11-libs/qt-sql-${PV}[sqlite]
	~x11-libs/qt-webkit-${PV}[=]
"
RDEPEND="${DEPEND}"

pkg_setup() {
	# Pixeltool isn't really assistant related, but it relies on
	# the assistant libraries. doc/qch/
	QT4_TARGET_DIRECTORIES="
		tools/assistant
		tools/pixeltool
		tools/qdoc3"
	QT4_EXTRACT_DIRECTORIES="
		tools/
		demos/
		examples/
		src/
		include/
		doc/"

	use trace && QT4_TARGET_DIRECTORIES="${QT4_TARGET_DIRECTORIES}
		tools/qttracereplay"
	QT4_EXTRACT_DIRECTORIES="${QT4_TARGET_DIRECTORIES}
		${QT4_EXTRACT_DIRECTORIES}"
	qt4-build_pkg_setup
}

src_prepare() {
	qt4-build_src_prepare
	sed -e "s/\(sub-qdoc3\.depends =\).*/\1/" \
		-i doc/doc.pri || die "patching qdoc3 depends failed"
}

src_configure() {
	myconf="${myconf} -no-xkb -no-fontconfig -no-xrandr
		-no-xfixes -no-xcursor -no-xinerama -no-xshape -no-sm -no-opengl
		-no-nas-sound -no-dbus -iconv -no-cups -no-nis -no-gif -no-libpng
		-no-libmng -no-libjpeg -no-openssl -system-zlib -no-phonon
		-no-xmlpatterns -no-freetype -no-libtiff -no-accessibility
		-no-fontconfig -no-multimedia -no-qt3support -no-svg"
	! use glib && myconf="${myconf} -no-glib"
	# https://bugreports.qt.nokia.com//browse/QTBUG-20236
	# Even though webkit option is included, we do not build
	# any targets
	myconf="${myconf} -webkit"
	qt4-build_src_configure
}

src_compile() {
	# help libQtHelp find freshly built libQtCLucene (bug #289811)
	export LD_LIBRARY_PATH="${S}/lib"
	qt4-build_src_compile
	# ugly hack to build docs
	cd "${S}"
	qmake "LIBS+=-L${QTLIBDIR}" "CONFIG+=nostrip" projects.pro || die
	emake qch_docs || die "emake qch_docs failed"
	if use doc; then
		emake docs || die "emake docs failed"
	fi
	qmake "LIBS+=-L${QTLIBDIR}" "CONFIG+=nostrip" projects.pro || die "qmake
	projects failed"
}

src_install() {
	qt4-build_src_install
	# install documentation
	# note that emake install_qchdocs fails for undefined reason so we use a
	# workaround
	cd "${S}"
	emake INSTALL_ROOT="${D}" install_qchdocs \
		|| die "emake install_qchdocs failed"
	dobin "${S}"/bin/qdoc3 || die "Installing qdoc3 failed"
	if use doc; then
		emake INSTALL_ROOT="${D}" install_qchdocs \
			|| die "emake install_qchdocs	failed"
	fi
	# install correct assistant icon, bug 241208
	dodir /usr/share/pixmaps/ || die "dodir failed"
	insinto /usr/share/pixmaps/ || die "insinto failed"
	doins tools/assistant/tools/assistant/images/assistant.png \
		|| die "doins failed"
	# Note: absolute image path required here!
	make_desktop_entry /usr/bin/assistant Assistant \
		/usr/share/pixmaps/assistant.png 'Qt;Development;GUIDesigner' \
			|| die "make_desktop_entry failed"

}